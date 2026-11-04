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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_symbollock.sv#6 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side symbol lock module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_symbollock

  import serdes_pipe_pkg::*;
#(
  parameter int  BUF_WD = $bits(pipe_data10b_t) + SYM_10B_WD - 2
) (
  // ------------- input -----------------
  input logic                              rx_clk,
  input logic                              rx_rst_n,
  input logic                              rx_sync_rst,
  input logic                              encdec_8b10b,
  input logic [PHY_10B_RAW_WD-1:0]         raw_width,
  input logic [$bits(pipe_data10b_t)-1:0]  pipe_rxdata,
  input logic [BUF_WD-1:0]                 buf_rxdata,
  input logic                              pipe_loopback_slave,
  input logic                              eios_found,
  // ------------- output ----------------
  output logic                             symbol_locked,
  output pipe_data10b_t                    locked_rxdata
);

// --------------------------------------------------------------------------------
//  Common internal parameter
// --------------------------------------------------------------------------------
  localparam int  GOOD_COM_TOL = 2;
  localparam int  BAD_COM_TOL  = 3;

  // This "TMP_WD" and "CDATA_WD" are there to avoid the Spyglass ImproperRangeIndex-ML   
  localparam int TMP_WD   = (1 << PHY_10B_RAW_WD) - 1;
  localparam int CDATA_WD = 1 << $clog2(TMP_WD + BUF_WD);

// --------------------------------------------------------------------------------
//  Common internal signal
// --------------------------------------------------------------------------------
  logic  lock_en;
  assign lock_en = encdec_8b10b && !pipe_loopback_slave;

  enum logic [1:0] {
    UNALIGNED,
    ALIGNED,
    LOCKED
  }  state, next_state;
  assign symbol_locked = (state == LOCKED);

  logic [PHY_10B_RAW_WD-1:0]  lock_offset;

  logic [CDATA_WD-1:0]  concat_rxdata;
  always_comb begin: concat_rxdata_PROC
    concat_rxdata = '0;
    concat_rxdata[$bits(pipe_data10b_t)+BUF_WD-1:0] = {pipe_rxdata, buf_rxdata};
  end: concat_rxdata_PROC

  logic [BUF_WD:0]   shifted_rxdata;
  assign shifted_rxdata = concat_rxdata[lock_offset+BUF_WD-:BUF_WD+1];

// --------------------------------------------------------------------------------
//  COM finding
// --------------------------------------------------------------------------------
  logic                       com_found;
  logic [PHY_10B_RAW_WD-1:0]  com_offset;

  always_comb begin: com_found_PROC
    logic [SYM_10B_WD-1:0]  l_rxdata;
    com_found = 1'h0;
    com_offset = '0;
    for(int i = 0; i < $bits(pipe_data10b_t); i++) begin
      if(i < raw_width) begin
        l_rxdata = {<< {concat_rxdata[BUF_WD+i-:SYM_10B_WD]}};
        if(l_rxdata inside {SYM_10B_COM, ~SYM_10B_COM}) begin
          com_found = 1'h1;
          com_offset = $bits(com_offset)'(i);
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  Aligned (good) / non-aligned (bad) COM detection
// --------------------------------------------------------------------------------
  logic  good_com_found;
  logic  bad_com_found;

  always_comb begin: good_com_found_PROC
    logic [SYM_10B_WD-1:0]  l_rxdata;
    good_com_found = 1'h0;
    bad_com_found = 1'h0;
    for(int i = 0; i < $bits(pipe_data10b_t); i++) begin
      if(i < raw_width) begin
        l_rxdata = {<< {shifted_rxdata[BUF_WD-i-:SYM_10B_WD]}};
        if(l_rxdata inside {SYM_10B_COM, ~SYM_10B_COM}) begin
          good_com_found |= ((i % SYM_10B_WD) == 0);
          bad_com_found |= ((i % SYM_10B_WD) != 0);
        end
      end
    end
  end

  logic [$clog2(GOOD_COM_TOL)-1:0]  good_com_cnt;
  logic                             good_com_cnt_expired;

  always_comb begin: good_com_cnt_expired_PROC
    good_com_cnt_expired = 1'h0;
    if(good_com_cnt == (GOOD_COM_TOL - 1)) begin
      if(good_com_found && !bad_com_found) begin
        good_com_cnt_expired = 1'h1;
      end
    end
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: good_com_cnt_PROC
    if(!rx_rst_n) begin
      good_com_cnt <= #`TP '0;
    end
    else if(rx_sync_rst || !lock_en) begin
      good_com_cnt <= #`TP '0;
    end
    else if(state != ALIGNED) begin
      good_com_cnt <= #`TP '0;
    end
    else begin
      if(good_com_cnt_expired) begin
        good_com_cnt <= #`TP '0;
      end
      else if(bad_com_found) begin
        good_com_cnt <= #`TP '0;
      end
      else if(good_com_found) begin
        good_com_cnt <= #`TP $bits(good_com_cnt)'(good_com_cnt + 1);
      end
    end
  end

  logic [$clog2(BAD_COM_TOL)-1:0]  bad_com_cnt;
  logic                            bad_com_cnt_expired;

  always_comb begin: bad_com_cont_expired_PROC
    bad_com_cnt_expired = 1'h0;
    if(bad_com_cnt == (BAD_COM_TOL - 1)) begin
      if(bad_com_found && !good_com_found) begin
        bad_com_cnt_expired = 1'h1;
      end
    end
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: bad_com_cnt_PROC
    if(!rx_rst_n) begin
      bad_com_cnt <= #`TP '0;
    end
    else if(rx_sync_rst || !lock_en) begin
      bad_com_cnt <= #`TP '0;
    end
    else if(state != LOCKED) begin
      bad_com_cnt <= #`TP '0;
    end
    else begin
      if(bad_com_cnt_expired) begin
        bad_com_cnt <= #`TP '0;
      end
      else if(good_com_found) begin
        bad_com_cnt <= #`TP '0;
      end
      else if(bad_com_found) begin
        bad_com_cnt <= #`TP $bits(bad_com_cnt)'(bad_com_cnt + 1);
      end
    end
  end

// --------------------------------------------------------------------------------
//  Symbol lock state machine
// --------------------------------------------------------------------------------
  always_comb begin: next_state_PROC
    next_state = state;
    case(state)
      UNALIGNED: begin
        if(com_found) begin
          next_state = ALIGNED;
        end
      end
      ALIGNED: begin
        if(bad_com_found) begin
          next_state = UNALIGNED;
        end
        else if(good_com_cnt_expired) begin
          next_state = LOCKED;
        end
      end
      LOCKED: begin
        if(eios_found || bad_com_cnt_expired) begin
          next_state = UNALIGNED;
        end
      end
    endcase
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: state_PROC
    if(!rx_rst_n) begin
      state <= #`TP UNALIGNED;
    end
    else if(rx_sync_rst) begin
      state <= #`TP UNALIGNED;
    end
    else if(lock_en) begin
      state <= #`TP next_state;
    end
  end

// --------------------------------------------------------------------------------
//  Lock offset
// --------------------------------------------------------------------------------
  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: lock_offset_PROC
    if(!rx_rst_n) begin
      lock_offset <= #`TP '0;
    end
    else if(rx_sync_rst) begin
      lock_offset <= #`TP '0;
    end
    else if(lock_en) begin
      if((state == UNALIGNED) && com_found) begin
        lock_offset <= #`TP com_offset;
      end
    end
  end

// --------------------------------------------------------------------------------
//  RxData shifting
// --------------------------------------------------------------------------------
  always_comb begin: locked_rxdata_PROC
    pipe_data10b_t  l_rxdata;
    l_rxdata = shifted_rxdata[SYM_10B_WD-1+:$bits(pipe_data10b_t)];
    for(int i = 0; i < $size(pipe_data10b_t); i++) begin
      locked_rxdata[i] = {<< {l_rxdata[i]}};
    end
  end

endmodule: serdes_pipe_rx_symbollock
