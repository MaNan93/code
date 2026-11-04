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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_128b130b_decode.sv#8 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side 128b/130b decode module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_128b130b_decode

  import serdes_pipe_pkg::*;
#(
  parameter int  BUF_WD = $bits(pipe_data128b_t) + $bits(pipe_syncheader_t) - 1
) (
  // ------------- input -----------------
  input logic                     rx_clk,
  input logic                     rx_rst_n,
  input logic                     rx_sync_rst,
  input logic                     sync_hdr_bypass_en,
  input logic [PHY_RAW_WD-1:0]    raw_width,
  input logic [PHY_SYM_WD-1:0]    symbol_width,
  input logic [RATE_WD-1:0]       pipe_rate,
  input pipe_data128b_t           pipe_rxdata,
  input logic [BUF_WD-1:0]        buf_rxdata,
  input logic                     block_aligned,
  input logic                     align_detected,
  input logic [PHY_RAW_WD-1:0]    align_offset,
  // ------------- output ----------------
  output pipe_data128b_t          decoded_rxdata,
  output logic                    decoded_rxdatavalid,
  output logic [PHY_RXSB_WD-1:0]  decoded_rxstartblock,
  output pipe_syncheader_t        decoded_rxsyncheader
);

// --------------------------------------------------------------------------------
//  Common internal parameter
// --------------------------------------------------------------------------------
  localparam int  SKPOS_HDR_WD = SYM_WD + SYNC_HDR_WD;

  localparam bit [SKPOS_HDR_WD-1:0]  GEN3_SKPOS_HDR = {SYM_GEN3_SKP, SYNC_HDR_OS};
  localparam bit [SKPOS_HDR_WD-1:0]  GEN5_SKPOS_HDR = {SYM_GEN5_SKP, SYNC_HDR_OS};

// --------------------------------------------------------------------------------
//  Common internal signal
// --------------------------------------------------------------------------------
  logic [SKPOS_HDR_WD-1:0]  skpos_hdr;

  always_comb begin: skpos_hdr_PROC
    case(pipe_rate)
      `GEN5_RATE: skpos_hdr = GEN5_SKPOS_HDR;
      default: skpos_hdr = GEN3_SKPOS_HDR;
    endcase
  end

  logic  decode_en;

  always_comb begin: decode_en_PROC
    decode_en = block_aligned;
    if(sync_hdr_bypass_en) begin
      decode_en = 1'h0;
    end
    else if (pipe_rate inside {`GEN6_RATE}) begin
      decode_en = 1'h0;
    end
  end

  logic [(BUF_WD*2):0]  concat_rxdata;
  assign concat_rxdata = $bits(concat_rxdata)'({pipe_rxdata, buf_rxdata});

  logic  symbol_width_4s;
  logic  symbol_width_8s;
  assign symbol_width_4s = (symbol_width == 4);
  assign symbol_width_8s = (symbol_width == 8);

// --------------------------------------------------------------------------------
//  RxData shifting
// --------------------------------------------------------------------------------
// spyglass disable_block W468
// SMD: Variable/signal which cannot index the full range of this vector.
// SJ: It is expected that 'buf_offset' only points to the first half part of 'concat_rxdata'.
  logic [BUF_WD:0]                                shifted_rxdata;
  logic [$clog2(BUF_WD+1)-1:0]                    buf_offset;
  logic                                           buf_offset_expired;
  logic [$clog2($bits(pipe_syncheader_t)+1)-1:0]  cur_syncheader_len;
  assign shifted_rxdata = concat_rxdata[buf_offset+:BUF_WD+1];
  assign buf_offset_expired = (buf_offset + cur_syncheader_len > BUF_WD);
// spyglass enable_block W468

  logic  align_adjusted;

  always_comb begin: align_adjusted_PROC
    align_adjusted = 1'h0;
    if(align_detected) begin
      if(!block_aligned) begin
        align_adjusted = 1'h1;
      end
      else begin
        align_adjusted = 1'h1;
        if(((align_offset + 1 + (BUF_WD - buf_offset)) & (raw_width - 1)) == 0) begin
          align_adjusted = 1'h0;
        end
        if(((align_offset + 1 + (BUF_WD - buf_offset)) & ((BLOCK_INT * SYM_WD) - 1)) == 0) begin
          // ccx_line: ; "Possibly redundunt line due to PHY_NB value."
          align_adjusted = 1'h0;
        end
      end
    end
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: buf_offset_PROC
    if(!rx_rst_n) begin
      buf_offset <= #`TP '0;
    end
    else if(rx_sync_rst) begin
      buf_offset <= #`TP '0;
    end
    else if(align_adjusted) begin
      buf_offset <= #`TP $bits(buf_offset)'(align_offset + 1 + (BUF_WD - raw_width));
    end
    else if(decode_en) begin
      if(buf_offset_expired) begin
        buf_offset <= #`TP $bits(buf_offset)'(buf_offset - raw_width);
      end
      else begin
        buf_offset <= #`TP $bits(buf_offset)'(buf_offset + cur_syncheader_len);
      end
    end
  end


// --------------------------------------------------------------------------------
//  Prefetching of 128b/130b decoded RxDataValid and RxStartblock
// --------------------------------------------------------------------------------
  logic                                pref_rxdatavalid;
  logic [PHY_RXSB_WD-1:0]              pref_rxstartblock;
  logic                                skp_finding, prev_skp_finding;
  logic [$clog2(BLOCK_SYM_NUM+1)-1:0]  os_symbol_cnt, prev_os_symbol_cnt;
  assign pref_rxdatavalid = decode_en && !buf_offset_expired;

  always_comb begin: pref_rxstartblock_PROC
    pref_rxstartblock = '0;
    cur_syncheader_len = '0;
    skp_finding = prev_skp_finding;
    os_symbol_cnt = prev_os_symbol_cnt;
    for(int i = 0; i < PHY_128B130B_NB; i++) begin
      if(symbol_width > i) begin
        // ccx_cond: ; 0; 10; "Possibly redundant condition due to PHY_NB value."
        if(((i % BLOCK_INT) == 0) && ((prev_os_symbol_cnt % BLOCK_INT) == 0)) begin
          if(skp_finding) begin
            if(shifted_rxdata[(SYM_WD*i)+cur_syncheader_len+:SYM_WD] != skpos_hdr[SYNC_HDR_WD+:SYM_WD]) begin
              skp_finding = 1'h0;
            end
            os_symbol_cnt = BLOCK_INT;
          end
          else if(os_symbol_cnt == 0) begin
            if(shifted_rxdata[(SYM_WD*i)+cur_syncheader_len+:SKPOS_HDR_WD] == skpos_hdr) begin
              skp_finding = 1'h1;
            end
            pref_rxstartblock[i/BLOCK_INT] = 1'h1;
            cur_syncheader_len = $bits(cur_syncheader_len)'(cur_syncheader_len + SYNC_HDR_WD);
            os_symbol_cnt = BLOCK_SYM_NUM;
          end
        end
        os_symbol_cnt = $bits(os_symbol_cnt)'(os_symbol_cnt - 1);
      end
    end
  end


  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: prev_skp_finding_PROC
    if(!rx_rst_n) begin
      prev_skp_finding <= #`TP 1'h0;
      prev_os_symbol_cnt <= #`TP '0;
    end
    else if(rx_sync_rst || !decode_en) begin
      prev_skp_finding <= #`TP 1'h0;
      prev_os_symbol_cnt <= #`TP '0;
    end
    else if(!buf_offset_expired) begin
      prev_skp_finding <= #`TP skp_finding;
      prev_os_symbol_cnt <= #`TP os_symbol_cnt;
    end
  end

// --------------------------------------------------------------------------------
//  Pipelining of prefetched RxDataValid and RxStartblock
// --------------------------------------------------------------------------------
  logic [BUF_WD:0]         pl_shifted_rxdata;
  logic                    pl_rxdatavalid;
  logic [PHY_RXSB_WD-1:0]  pl_rxstartblock;

  delay_n
   #(
    .N(0),
    .WD($bits({shifted_rxdata, pref_rxdatavalid, pref_rxstartblock}))
  ) u_delay_n_pref (
    .clk(rx_clk),
    .rst_n(rx_rst_n),
    .clear(rx_sync_rst),
    .din({shifted_rxdata, pref_rxdatavalid, pref_rxstartblock}),
    .dout({pl_shifted_rxdata, pl_rxdatavalid, pl_rxstartblock})
  );

// --------------------------------------------------------------------------------
//  128b/130b decoding using prefetched RxStartblock
// --------------------------------------------------------------------------------
  pipe_data128b_t    pre_rxdata;
  pipe_syncheader_t  pre_rxsyncheader;

  always_comb begin: pre_rxdata_PROC
    logic [$clog2($bits(pipe_syncheader_t)+1)-1:0]  l_syncheader_len;
    l_syncheader_len = '0;
    pre_rxdata = '0;
    pre_rxsyncheader = '0;
    for(int i = 0; i < PHY_128B130B_NB; i++) begin
      if((i % BLOCK_INT) == 0) begin
        if(pl_rxstartblock[i/BLOCK_INT]) begin
          pre_rxsyncheader[i/BLOCK_INT] = pl_shifted_rxdata[(SYM_WD*i)+l_syncheader_len+:SYNC_HDR_WD];
          l_syncheader_len = $bits(l_syncheader_len)'(l_syncheader_len + SYNC_HDR_WD);
        end
      end
      pre_rxdata[i] = pl_shifted_rxdata[(SYM_WD*i)+l_syncheader_len+:SYM_WD];
    end
  end

  delay_n
   #(
    .N(1),
    .WD($bits({pre_rxdata, pl_rxdatavalid, pl_rxstartblock, pre_rxsyncheader}))
  ) u_delay_n_regout (
    // ------------- input -----------------
    .clk(rx_clk),
    .rst_n(rx_rst_n),
    .clear(rx_sync_rst),
    .din({pre_rxdata, pl_rxdatavalid, pl_rxstartblock, pre_rxsyncheader}),
    // ------------- output ----------------
    .dout({decoded_rxdata, decoded_rxdatavalid, decoded_rxstartblock, decoded_rxsyncheader})
  );

endmodule: serdes_pipe_rx_128b130b_decode
