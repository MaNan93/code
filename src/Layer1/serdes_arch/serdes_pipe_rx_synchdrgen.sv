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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_synchdrgen.sv#10 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side sync header generation module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_synchdrgen

  import serdes_pipe_pkg::*;
#(
  parameter int  BUF_WD = $bits(pipe_data128b_t) - 1
) (
  // ------------- input -----------------
  input logic                               rx_clk,
  input logic                               rx_rst_n,
  input logic                               rx_sync_rst,
  input logic                               sync_hdr_bypass_en,
  input logic                               flit_mode_enable,
  input logic [9:0]                         skpos_interval_block_num,
  input logic                               loopback_state,
  input logic                               poll_compliance_state,
  input logic                               pipe_srisen,
  input logic [PHY_RAW_WD-1:0]              raw_width,
  input logic [PHY_SYM_WD-1:0]              symbol_width,
  input logic [RATE_WD-1:0]                 pipe_rate,
  input logic                               pipe_rxvalid,
  input logic [$bits(pipe_data128b_t)-1:0]  pipe_rxdata,
  input logic [BUF_WD-1:0]                  buf_rxdata,
  input logic                               block_aligned,
  input logic                               align_detected,
  input logic [PHY_RAW_WD-1:0]              align_offset,
  input logic                               skpos_found,
  input logic                               sdsos_found,
  input logic                               eios_found,
  input logic                               eieos_found,
  input logic                               eieos_str_found,
  input logic                               skpos_last_symbol,
  // ------------- output ----------------
  output pipe_data128b_t                    bypassed_rxdata,
  output logic                              bypassed_rxdatavalid,
  output logic [PHY_RXSB_WD-1:0]            bypassed_rxstartblock,
  output pipe_syncheader_t                  bypassed_rxsyncheader,
  output logic [5:0]                        symbol_cnt,
  output logic                              symbol_cnt_adjust,
  output logic                              in_datastream,
  output logic                              err_skp_after_sds,
  output logic                              err_syncheader_bypass
);

// --------------------------------------------------------------------------------
//  Common internal parameter
// --------------------------------------------------------------------------------
  localparam int  OS_BLOCK_INT = 341 + 407 ;
  localparam int  OS_BLOCK_CXL_INT = 341;

  logic [8:0]  os_interval_in_1b1b_mod_compliance;
  always_comb begin: os_interval_in_1b1b_mod_compliance_PROC
    os_interval_in_1b1b_mod_compliance = 'd256;
    if(pipe_srisen) begin
      os_interval_in_1b1b_mod_compliance = 'd32;
    end
  end

// --------------------------------------------------------------------------------
//  Common internal signal
// --------------------------------------------------------------------------------
  logic  synchdrgen_en, pre_synchdrgen_en;

  always_comb begin: pre_synchdrgen_en_PROC
    pre_synchdrgen_en = 1'h0;
    if(pipe_rxvalid) begin
      if(sync_hdr_bypass_en || (pipe_rate inside {`GEN6_RATE})) begin
        if(block_aligned) begin
          pre_synchdrgen_en = 1'h1;
        end
      end
    end
  end

  // Automotive requirement: cxl_auto_1.
  enum logic [1:0] {
    OSSTREAM   = 'b01,
    DATASTREAM = 'b10
  }  synchdrgen_state, next_synchdrgen_state;

  logic                               wait_skp_after_sds;
  assign in_datastream = (synchdrgen_state == DATASTREAM) && !poll_compliance_state  && !wait_skp_after_sds ;
// --------------------------------------------------------------------------------
//  RxData shifting
// --------------------------------------------------------------------------------
  logic [$bits(pipe_rxdata)+BUF_WD-1:0]  concat_rxdata;
  assign concat_rxdata = {pipe_rxdata, buf_rxdata};

  logic [$clog2(BUF_WD+1)-1:0]  buf_offset;


  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: buf_offset_PROC
    if(!rx_rst_n) begin
      buf_offset <= #`TP '0;
    end
    else if(rx_sync_rst) begin
      buf_offset <= #`TP '0;
    end
    else if(sync_hdr_bypass_en || (pipe_rate inside {`GEN6_RATE})) begin
  // temporary cahnge for HW test Start
      if(align_detected ) begin
  // temporary cahnge for HW test End
        buf_offset <= #`TP $bits(buf_offset)'(align_offset + 1 + (BUF_WD - raw_width));
      end
    end
  end

// spyglass disable_block W468
// SMD: Variable/signal which cannot index the full range of this vector.
// SJ: It is expected that 'buf_offset' only points to the first half part of 'concat_rxdata'.
  pipe_data128b_t  shifted_rxdata, pre_shifted_rxdata;
  assign pre_shifted_rxdata = concat_rxdata[buf_offset+:$bits(pre_shifted_rxdata)];
// spyglass enable_block W468
  logic      post_align_detected ;
  localparam N_DLY  = `CX_SERDES_ARCH_RX_SH_BYPASS_BYPSDATA_REGOUT ;
  delay_n
   #(
    .N(N_DLY),
    .WD($bits({pre_shifted_rxdata, pre_synchdrgen_en, align_detected}))
  ) u_delay_n_pref (
    .clk(rx_clk),
    .rst_n(rx_rst_n),
    .clear(rx_sync_rst),
    .din({pre_shifted_rxdata, pre_synchdrgen_en, align_detected}),
    .dout({shifted_rxdata, synchdrgen_en, post_align_detected})
  );

// --------------------------------------------------------------------------------
//  Syncheader Generation
// --------------------------------------------------------------------------------
  logic [5:0]                          next_symbol_cnt;
  logic                                symbol_cnt_expired;
  logic                                symbol_cnt_zero;

  assign next_symbol_cnt = $bits(next_symbol_cnt)'(symbol_cnt + symbol_width);
  assign symbol_cnt_zero = (symbol_cnt == '0);

  always_comb begin: symbol_cnt_expired_PROC
    symbol_cnt_expired = (next_symbol_cnt == $bits(next_symbol_cnt)'(BLOCK_SYM_NUM));
    if(skpos_found && (pipe_rate == `GEN6_RATE)) begin
      symbol_cnt_expired = skpos_last_symbol;
    end
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: symbol_cnt_PROC
    if(!rx_rst_n) begin
      symbol_cnt <= #`TP '0;
    end
    else if(rx_sync_rst || !synchdrgen_en) begin
      symbol_cnt <= #`TP '0;
    end
    else if(symbol_cnt_adjust) begin
      symbol_cnt <= #`TP '0;
    end
    else begin
      symbol_cnt <= #`TP (symbol_cnt_expired) ? '0 : next_symbol_cnt;
    end
  end

  logic [$clog2(OS_BLOCK_INT+1)-1:0]  block_cnt, next_block_cnt;
  logic                               block_cnt_expired;
  logic                               wait_back_to_back_skp_in_loopback;
  assign next_block_cnt = $bits(block_cnt)'(block_cnt + 1);

  always_comb begin: block_cnt_expired_PROC
    // CXL default
    block_cnt_expired = (next_block_cnt == $bits(next_block_cnt)'(OS_BLOCK_CXL_INT));
    if(pipe_rate == `GEN6_RATE) begin
      block_cnt_expired = (next_block_cnt == $bits(next_block_cnt)'(skpos_interval_block_num + 1));
      if(poll_compliance_state) begin  // For Received mod compliance pattern
        block_cnt_expired = (next_block_cnt == $bits(next_block_cnt)'(os_interval_in_1b1b_mod_compliance + 1));
      end
    end
    if(sync_hdr_bypass_en && flit_mode_enable) begin 
      block_cnt_expired = (next_block_cnt == $bits(next_block_cnt)'(skpos_interval_block_num + 1));
    end
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: block_cnt_PROC
    if(!rx_rst_n) begin
      block_cnt <= #`TP '0;
    end
    else if(rx_sync_rst || !synchdrgen_en) begin
      block_cnt <= #`TP '0;
    end
    else if((synchdrgen_state == DATASTREAM)
           && (!wait_skp_after_sds && !wait_back_to_back_skp_in_loopback)
           ) begin
      if(symbol_cnt_expired) begin
        block_cnt <= #`TP (block_cnt_expired) ? '0 : next_block_cnt;
      end
    end
    else begin
      block_cnt <= #`TP '0;
    end
  end

  logic                    gen_startblock;
  logic [SYNC_HDR_WD-1:0]  gen_syncheader;
  assign gen_startblock = symbol_cnt_zero;

  always_comb begin: gen_syncheader_PROC
    gen_syncheader = '0;
    if(gen_startblock) begin
      case(synchdrgen_state)
        OSSTREAM: gen_syncheader = SYNC_HDR_OS;
        DATASTREAM: begin
          if (
               (wait_skp_after_sds || wait_back_to_back_skp_in_loopback) ||
               block_cnt_expired                                                                     // Common for all encoding
          ) begin
            gen_syncheader = SYNC_HDR_OS;
          end else begin
            gen_syncheader = SYNC_HDR_DATA;
          end
        end
        // Automotive requirement: cxl_auto_1.
        default: gen_syncheader = '0;
      endcase
    end
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: wait_skp_after_sds_PROC
    if(!rx_rst_n) begin
      wait_skp_after_sds <= #`TP 1'h0;
    end
    else if(rx_sync_rst || !synchdrgen_en || skpos_last_symbol) begin
      wait_skp_after_sds <= #`TP 1'h0;
    end
    // Tied to 0b when Syncheader bypass with 68B flit mode (flit_mode_enable == 0b)
    // skpos_found: clear wait_skp_after_sds when skpos_found is asserted for sync_hdr_bypass_en && pcie flit mode
    else if( (sync_hdr_bypass_en && !flit_mode_enable) || (skpos_found && sync_hdr_bypass_en && flit_mode_enable) ) begin       
      wait_skp_after_sds <= #`TP 1'h0;
    end
    else if(sdsos_found) begin
      wait_skp_after_sds <= #`TP 1'b1;
    end
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: wait_back_to_back_skp_in_loopback_PROC
    if(!rx_rst_n) begin
      wait_back_to_back_skp_in_loopback <= #`TP 1'h0;
    end
    else if(rx_sync_rst || !synchdrgen_en || !loopback_state || !(synchdrgen_state == DATASTREAM)) begin
      wait_back_to_back_skp_in_loopback <= #`TP 1'h0;
    end
    // When in Loopback state and Data stream
    else if(skpos_last_symbol) begin
      if(!wait_back_to_back_skp_in_loopback) begin
        wait_back_to_back_skp_in_loopback <= #`TP 1'b1;
      end
      else begin
        wait_back_to_back_skp_in_loopback <= #`TP 1'b0;
      end
    end
  end


// --------------------------------------------------------------------------------
//  Symbol counter adjustment
// --------------------------------------------------------------------------------
  logic adjust_mask;
  
  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: adjust_mask_PROC
    if(!rx_rst_n) begin
      adjust_mask <= #`TP 1'h0;
    end
    else if(rx_sync_rst) begin
      adjust_mask <= #`TP 1'h0;
    end
    else if(eieos_str_found) begin
      adjust_mask <= #`TP 1'h1;
    end
    else if(symbol_cnt_expired) begin
      adjust_mask <= #`TP 1'h0;
    end
  end

  always_comb begin: symbol_cnt_adjust_PROC
    symbol_cnt_adjust = post_align_detected && !symbol_cnt_expired; // For Non-Gen5(1 EIEOS)
    if(pipe_rate == RATE_WD'(`GEN5_RATE)) begin
      symbol_cnt_adjust = post_align_detected && !symbol_cnt_expired && eieos_str_found && !adjust_mask ; // For Gen5(2 EIEOS)
    end
  end

// --------------------------------------------------------------------------------
//  Syncheader Generation FSM
// --------------------------------------------------------------------------------
  logic start_data_stream;
  
  always_comb begin: start_data_stream_PROC
    start_data_stream = sdsos_found;
    if(pipe_rate == RATE_WD'(`GEN6_RATE)) begin
      start_data_stream = sdsos_found/*TBD*/;
    end
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: synchdrgen_state_PROC
    if(!rx_rst_n) begin
      synchdrgen_state <= #`TP OSSTREAM;
    end
    else if(pipe_rate == RATE_WD'(`GEN6_RATE) && poll_compliance_state && eieos_str_found && !block_aligned) begin
      synchdrgen_state <= #`TP DATASTREAM;
    end
    else if(rx_sync_rst || !synchdrgen_en) begin
      synchdrgen_state <= #`TP OSSTREAM;
    end
    else begin
      synchdrgen_state <= #`TP next_synchdrgen_state;
    end
  end

  always_comb begin: next_synchdrgen_state_PROC
    next_synchdrgen_state = synchdrgen_state;
    case(synchdrgen_state)
      OSSTREAM: begin
        if(start_data_stream) begin
          next_synchdrgen_state = DATASTREAM;
        end
      end
      DATASTREAM: begin
        if(symbol_cnt_expired && block_cnt_expired) begin
          if(eios_found || eieos_found) begin
            next_synchdrgen_state = OSSTREAM;
          end
        end
        if(pipe_rate == RATE_WD'(`GEN6_RATE) && poll_compliance_state) begin
          next_synchdrgen_state = synchdrgen_state;
        end
      end
      default: next_synchdrgen_state = synchdrgen_state;
    endcase
  end

// --------------------------------------------------------------------------------
//  Error detection
// --------------------------------------------------------------------------------
  always_comb begin: err_syncheader_bypass_PROC
    err_syncheader_bypass = 1'h0;
    if(synchdrgen_state == DATASTREAM) begin
      if(symbol_cnt_expired && block_cnt_expired) begin
        if(!(skpos_found || eieos_found || eios_found)) begin
          err_syncheader_bypass = 1'h1;
        end
      end
    end
    if(pipe_rate == RATE_WD'(`GEN6_RATE) && poll_compliance_state) begin
      err_syncheader_bypass = 1'h0;
    end
  end

  always_comb begin: err_skp_after_sds_PROC
    err_skp_after_sds = 1'h0;
    if(pipe_rate == RATE_WD'(`GEN6_RATE) || (sync_hdr_bypass_en && flit_mode_enable) ) begin
      if(symbol_cnt_expired && wait_skp_after_sds) begin
        if(!(skpos_found || sdsos_found)) begin
          err_skp_after_sds = 1'h1;
        end
      end
    end
  end
// --------------------------------------------------------------------------------
//  Data output
// --------------------------------------------------------------------------------

  assign bypassed_rxdatavalid = synchdrgen_en;

  always_comb begin: bypassed_rxdata_PROC
    bypassed_rxdata = '0;
    bypassed_rxstartblock = '0;
    bypassed_rxsyncheader = '0;
    if(bypassed_rxdatavalid) begin
      for(int i = 0; i < PHY_NB; i++) begin
        if(symbol_width > i) begin
          bypassed_rxdata[i] = shifted_rxdata[i];
        end
      end
      bypassed_rxstartblock[0] = gen_startblock;
      bypassed_rxsyncheader[0] = gen_syncheader;
    end
  end  


endmodule: serdes_pipe_rx_synchdrgen
