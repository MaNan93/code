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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_tx_128b130b_encode.sv#8 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture transmitter side 128b/130b encode module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_tx_128b130b_encode

  import serdes_pipe_pkg::*;
(
  // ------------ inputs ----------------
  input logic                     clk,
  input logic                     rst_n,
  input logic                     encdec_8b10b,
  input logic                     loopback_en,
  input logic  [PHY_SYM_WD-1:0]   symbol_width,
  input logic  [PHY_RAW_WD-1:0]   raw_width,
  input logic  [ORIG_DATA_WD-1:0] data_in,
  input logic                     datavalid,
  input logic  [PHY_RXSB_WD-1:0]  startblock,
  input logic  [PHY_RXSH_WD-1:0]  syncheader,
  input logic                     elecidle_in,
  input logic                     rd_datavalid,
  // ------------ outputs ----------------
  output logic [ORIG_DATA_WD-1:0] enc_data,
  output logic [PHY_TXEI_WD-1:0]  elecidle_out
);

  localparam int DATA_HDR_WD = ORIG_DATA_WD + PHY_RXSH_WD;

  // This "TMP_WD" is there to avoid the Spyglass ImproperRangeIndex-ML
  localparam int TMP_WD = 1 << ($clog2(DATA_HDR_WD+1)+1);

  logic wr_datavalid;
  assign wr_datavalid = datavalid;
// --------------------------------------------------------------------------------
//  Create encode enable flag 
// --------------------------------------------------------------------------------

  logic valid_elecidle_in;
  logic enc_en;

  assign enc_en = (encdec_8b10b) ? 1'h0 : !valid_elecidle_in; 

  always_comb begin: valid_elecidle_in_PROC
    valid_elecidle_in = elecidle_in;
  end: valid_elecidle_in_PROC
// --------------------------------------------------------------------------------
//  Create loopback flag
// --------------------------------------------------------------------------------
  logic loopback_en_d;
  logic loopback_start;
  logic loopback_end;

  assign loopback_start  = (loopback_en && !loopback_en_d);
  assign loopback_end    = (!loopback_en && loopback_en_d);

  always_ff @ (posedge clk or negedge rst_n) begin: loopback_en_d_PROC
    if (!rst_n) begin
      loopback_en_d <= #`TP 1'b0;
    end
    else begin
      loopback_en_d <= #`TP loopback_en;
    end
  end: loopback_en_d_PROC

// --------------------------------------------------------------------------------
// Create dead cycle flag 
// --------------------------------------------------------------------------------

  logic dead_cycle;
  always_comb begin: dead_cycle_PROC
    dead_cycle = enc_en && !wr_datavalid;
  end: dead_cycle_PROC

// --------------------------------------------------------------------------------
//  Create current cycle data including sync header
// --------------------------------------------------------------------------------
  logic [DATA_HDR_WD-1:0] cur_data, valid_cur_data;

  // This tmp_valid_cur_data is a signal to avoid the Spyglass ImproperRangeIndex-ML 
  logic [TMP_WD-1:0] tmp_valid_cur_data;

  assign valid_cur_data = tmp_valid_cur_data[DATA_HDR_WD-1:0];

// spyglass disable_block W468
// SMD: Variable/signal which cannot index the full range of this vector.
// SJ: It is expected that 'data_width' only points to the first half part of 'tmp_valid_cur_data'.
// spyglass disable_block AlwaysCombExhaustive-ML
// SMD: Not all conditions are covered for the combinational logic.
// SJ: A default value is defined to avoid a latch.
  always_comb begin: tmp_valid_cur_data_PROC
    logic [$clog2(DATA_HDR_WD+1)-1:0] data_width;
    data_width = '0;
    tmp_valid_cur_data = '0;
    if (enc_en && wr_datavalid)begin
      for(int i = 0; i < PHY_128B130B_NB; i++) begin
        if((i % BLOCK_INT) == 0) begin
          if(startblock[i/BLOCK_INT]) begin
            tmp_valid_cur_data[data_width +:SYNC_HDR_WD] = syncheader[SYNC_HDR_WD*(i/BLOCK_INT) +:SYNC_HDR_WD];
            data_width += SYNC_HDR_WD;
          end
        end
        tmp_valid_cur_data[data_width +:SYM_WD] = data_in[SYM_WD*i +:SYM_WD];
        data_width += SYM_WD;
      end
    end
  end: tmp_valid_cur_data_PROC
// spyglass enable_block W468
// spyglass enable_block AlwaysCombExhaustive-ML


  always_comb begin: cur_data_PROC
    cur_data = valid_cur_data;
  end: cur_data_PROC

// --------------------------------------------------------------------------------
//  Create current syncheader width
// --------------------------------------------------------------------------------
  logic [$clog2(PHY_RXSH_WD+1)-1:0]  cur_syncheader_width, valid_syncheader_width;

  always_comb begin: valid_syncheader_width_PROC
    valid_syncheader_width = '0;
    if(enc_en && wr_datavalid) begin
      for(int i = 0; i < PHY_RXSB_WD; i++) begin
        if(startblock[i]) begin
          valid_syncheader_width += SYNC_HDR_WD;
        end
      end
    end
  end: valid_syncheader_width_PROC


  always_comb begin: cur_syncheader_width_PROC
    cur_syncheader_width = valid_syncheader_width;
  end: cur_syncheader_width_PROC

// --------------------------------------------------------------------------------
//  Create preveous cycle data including sync header
// --------------------------------------------------------------------------------
  logic [DATA_HDR_WD-1:0]            prev_data;
  logic [DATA_HDR_WD-1:0]            cur_data_ljust;

  assign cur_data_ljust = cur_data << (DATA_HDR_WD - (raw_width + cur_syncheader_width));

  always_ff @(posedge clk or negedge rst_n) begin: prev_data_PROC
    if(!rst_n) begin
      prev_data <= #`TP '0;
    end 
    else if (rd_datavalid && !dead_cycle) begin
      prev_data <= #`TP cur_data_ljust;
    end
  end: prev_data_PROC

// --------------------------------------------------------------------------------
//  Sync header counter
// --------------------------------------------------------------------------------

  logic [$clog2(DATA_HDR_WD+1)-1:0] syncheader_width_cnt;

  always_ff @(posedge clk or negedge rst_n) begin: syncheader_width_cnt_PROC
    if(!rst_n) begin
      syncheader_width_cnt <= #`TP '0;
    end 
    else if (!enc_en) begin
      syncheader_width_cnt <= #`TP '0;
    end 
    else if (loopback_start) begin
      if(rd_datavalid) begin
        syncheader_width_cnt <= #`TP $bits(syncheader_width_cnt)'(cur_syncheader_width);
      end 
      else begin
        syncheader_width_cnt <= #`TP '0;
      end  
    end 
    else if (dead_cycle) begin
      if(syncheader_width_cnt > raw_width) begin
        syncheader_width_cnt <= #`TP $bits(syncheader_width_cnt)'(syncheader_width_cnt - raw_width);
      end 
      else begin
        syncheader_width_cnt <= #`TP '0;
      end  
    end 
    else if (rd_datavalid)begin
      syncheader_width_cnt <= #`TP $bits(syncheader_width_cnt)'(syncheader_width_cnt + cur_syncheader_width);
    end
  end: syncheader_width_cnt_PROC

// --------------------------------------------------------------------------------
//  Create encoded data
// --------------------------------------------------------------------------------
// spyglass disable_block W468
// SMD: Variable/signal which cannot index the full range of this vector.
// SJ: It is expected that 'lsb_loc' range is 0 - ORIG_DATA_WD and it only points to the first half part of 'concat_data'.
  logic [$clog2(ORIG_DATA_WD+1)-1:0]  lsb_loc;
  logic [DATA_HDR_WD+DATA_HDR_WD-1:0] concat_data;
  logic [ORIG_DATA_WD-1:0]            cut_data;

  assign lsb_loc     = (loopback_start) ? DATA_HDR_WD : DATA_HDR_WD - syncheader_width_cnt;
  assign concat_data = (loopback_end)   ? '0 : {cur_data,prev_data};
  assign cut_data    = (lsb_loc > DATA_HDR_WD) ? '0  : concat_data[lsb_loc+:ORIG_DATA_WD];
// spyglass enable_block W468

  always_comb begin: enc_data_PROC
    enc_data = '0;
    for(int i = 0; i < PHY_NB; i++) begin
      if((symbol_width > i) && rd_datavalid)begin
        enc_data[i*SYM_WD +:SYM_WD] = cut_data[i*SYM_WD +:SYM_WD];
      end
    end
  end: enc_data_PROC

// --------------------------------------------------------------------------------
//  Create SerDes TxElecIdle
// --------------------------------------------------------------------------------

  integer valid_ei_width;

  // ccx_cond: ; 0; 1; "Possibly redundant condition due to PHY_NB value."
  assign valid_ei_width = (symbol_width == 1) ? 1 : symbol_width/2;

  always_comb begin: elecidle_out_PROC
    if(!valid_elecidle_in) begin
      elecidle_out = '0;
    end
    else if(loopback_end) begin
      elecidle_out = '1;
    end
    else begin
      for(int i = 0; i < $bits(elecidle_out); i++) begin
        if(i < valid_ei_width) begin
          elecidle_out[i] = (syncheader_width_cnt > (SYM_WD*2)*i) ? 1'h0 : 1'h1;
        end
        else begin
          elecidle_out[i] = (syncheader_width_cnt > (SYM_WD*2)*(valid_ei_width-1)) ? 1'h0 : 1'h1;
        end
      end
    end
  end: elecidle_out_PROC

endmodule
