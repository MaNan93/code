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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_1b1b_osfind.sv#4 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side 1b/1b Ordered Set find module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_1b1b_osfind

  import serdes_pipe_pkg::*;
(
  // ------------- input -----------------
  input logic                    rx_clk,
  input logic                    rx_rst_n,
  input logic                    rx_sync_rst,
  input logic [PHY_SYM_WD-1:0]   symbol_width,
  input logic [RATE_WD-1:0]      pipe_rate,
  input logic                    flit_mode_enable,
  input logic                    block_aligned,
  input logic [5:0]              symbol_cnt,
  input logic                    symbol_cnt_adjust,
  input logic                    in_datastream,
  input logic                    poll_compliance_state,
  input pipe_data128b_t          decoded_rxdata,
  input logic                    decoded_rxdatavalid,
  input logic [PHY_RXSB_WD-1:0]  decoded_rxstartblock,
  input pipe_syncheader_t        decoded_rxsyncheader,
  // ------------- output ----------------
  output logic                   sdsos_found,
  output logic                   skpos_found,
  output logic                   eieos_found,
  output logic                   skpos_last_symbol,
  output logic                   skp_end_found_gen6,
  output logic                   eios_found,
  output logic                   err_skp_wo_skp_end
  ,
  output logic                   os_corrected
);

// --------------------------------------------------------------------------------
//  Common internal parameter
// --------------------------------------------------------------------------------
  localparam LOG2_BLOCK_INT_GEN6 = $clog2(BLOCK_INT_GEN6);

// --------------------------------------------------------------------------------
//  Common internal type
// --------------------------------------------------------------------------------

  typedef struct packed {
    logic [OS_FIND_GEN6_NB-1:0]  match_bitmap;
    logic [OS_FIND_GEN6_WD-1:0]  match_1st;
    logic [OS_FIND_GEN6_WD-1:0]  valid_sym_cnt_in_first_8byte;
  }  eiosfind_gen6_t;

  typedef struct packed {
    logic [OS_FIND_GEN6_NB-1:0]  match_bitmap;
    logic [OS_FIND_GEN6_NB-1:0]  match_bitmap_1b_mismatch;
    logic [OS_FIND_GEN6_WD-1:0]  match_1st;
    logic [OS_FIND_GEN6_WD-1:0]  valid_sym_cnt_in_first_8byte;
  }  eieosfind_gen6_t;

  typedef struct packed {
    logic [OS_FIND_GEN6_NB-1:0]  match_bitmap;
    logic [OS_FIND_GEN6_NB-1:0]  match_bitmap_skpend;
    logic [OS_FIND_GEN6_WD-1:0]  match_1st;
    logic [OS_FIND_GEN6_WD-1:0]  valid_sym_cnt_in_first_8byte;
    logic [OS_FIND_GEN6_WD-1:0]  valid_sym_cnt_skpend_8byte;
    logic [OS_FIND_GEN6_WD-1:0]  valid_find_skpos;
    logic                        crry_over_find_skpos;
    logic [5:0]                  crry_over_cnt_symbol;
  }  skposfind_gen6_t;


  typedef struct packed {
    logic [PHY_NB-1:0]           match_bitmap;
    logic [OS_FIND_GEN6_WD-1:0]  match_1st;
    logic [PHY_NB/4-1:0]         good_sds_4byte;
    logic [4:0]                  crry_over_cnt_symbol;
    logic [2:0]                  crry_over_cnt_any_good_4byte;
    logic [2:0]                  crry_over_cnt_even_good_4byte;
  }  sdsosfind_gen6_t;

// --------------------------------------------------------------------------------
//  Common internal signal
// -------------------------------------------------------------------------------

  logic  osfind_en;
  assign osfind_en = block_aligned;

// --------------------------------------------------------------------------------
//  OS symbol decoding
// --------------------------------------------------------------------------------
  logic [PHY_NB-1:0] skp_id_found, skp_end_found;
  logic [PHY_NB-1:0] ei_found;
  logic [PHY_NB-1:0] sds_id_found;

  always_comb begin: skp_id_found_PROC
    skp_id_found = '0;
    skp_end_found = '0;
    ei_found = '0;
    sds_id_found = '0;
    for(int i = 0; i < PHY_NB; i++) begin
      if(pipe_rate == `GEN6_RATE) begin
        // SKP, EIOS
        if(i % 2 == 0) begin
          skp_id_found[i] = (decoded_rxdata[i] == 'hF0);
          ei_found[i] = (decoded_rxdata[i] == 'h0F);
        end
        else begin
          skp_id_found[i] = (decoded_rxdata[i] == 'h0F);
          ei_found[i] = (decoded_rxdata[i] == 'hF0);
        end
        // SKP END
        if(i % 4 == 0) begin
          skp_end_found[i] = (decoded_rxdata[i] == 'hFF);
        end
        else if(i % 4 == 2) begin
          skp_end_found[i] = (decoded_rxdata[i] == 'h00);
        end
        else begin
          skp_end_found[i] = (decoded_rxdata[i] == 'hF0);
        end
        // SDS
        if(!in_datastream) begin // To avoid to detect SDSOS from Data block
          if(i % 4 == 0) begin
            sds_id_found[i] = (decoded_rxdata[i] == 'hB1);
          end
          else begin
            sds_id_found[i] = (decoded_rxdata[i] == 'hC6);
          end
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  OS finding
// --------------------------------------------------------------------------------

  logic  [OS_FIND_GEN6_WD-1:0] raw_eios_found_gen6;
  logic  [OS_FIND_GEN6_WD-1:0] raw_eieos_found_gen6;
  // temporary cahnge for HW test Start
  // temporary cahnge for HW test End
  logic  [OS_FIND_GEN6_WD-1:0] raw_skpos_found_gen6;
  logic  [OS_FIND_GEN6_WD-1:0] raw_sdsos_found_gen6;
  
  eiosfind_gen6_t  eios_finding_gen6, prev_eios_finding_gen6;
  eieosfind_gen6_t eieos_finding_gen6, prev_eieos_finding_gen6;
  skposfind_gen6_t skpos_finding_gen6, prev_skpos_finding_gen6;
  sdsosfind_gen6_t sdsos_finding_gen6, prev_sdsos_finding_gen6;

  // For 8s or lower, latched the eios_finding_gen6 info of 1st 8 byte.
  eiosfind_gen6_t  latched_1st_8byte_eios_finding_gen6;
  eieosfind_gen6_t latched_1st_8byte_eieos_finding_gen6;
  
  logic  [PHY_NB-1:0]         exp_eieos ;          // 0; 00h , 1; AAh
  logic  [PHY_NB-1:0]         revert_exp_eieos ;   // 0; 00h , 1; AAh

  always_comb begin: eios_found_PROC
    eios_found = 1'h0;
    eieos_found = 1'h0;
    skpos_found = 1'h0;
    sdsos_found = 1'h0;
    if(osfind_en) begin
      if(decoded_rxdatavalid) begin
        if(pipe_rate == `GEN6_RATE) begin
          eios_found  = |raw_eios_found_gen6;
          eieos_found = |raw_eieos_found_gen6;
          skpos_found = skpos_finding_gen6.crry_over_find_skpos || (|raw_skpos_found_gen6);
          sdsos_found = |raw_sdsos_found_gen6;
        end
      end
    end
  end


  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: prev_eios_finding_gen6_PROC
    if(!rx_rst_n) begin
      prev_eios_finding_gen6 <= #`TP '{default: 0};
      prev_eieos_finding_gen6 <= #`TP '{default: 0};
      prev_skpos_finding_gen6 <= #`TP '{default: 0};
      prev_sdsos_finding_gen6 <= #`TP '{default: 0};
      revert_exp_eieos        <= #`TP 0;
    end
    else if(rx_sync_rst || !osfind_en || symbol_cnt_adjust) begin
      prev_eios_finding_gen6 <= #`TP '{default: 0};
      prev_eieos_finding_gen6 <= #`TP '{default: 0};
      prev_skpos_finding_gen6 <= #`TP '{default: 0};
      prev_sdsos_finding_gen6 <= #`TP '{default: 0};
      revert_exp_eieos        <= #`TP 0;
    end
    else if(decoded_rxdatavalid) begin
      prev_eios_finding_gen6 <= #`TP eios_finding_gen6;
      prev_eieos_finding_gen6 <= #`TP eieos_finding_gen6;
      prev_skpos_finding_gen6 <= #`TP skpos_finding_gen6;
      prev_sdsos_finding_gen6 <= #`TP sdsos_finding_gen6;
      revert_exp_eieos        <= #`TP ~exp_eieos;
    end
  end

  // For 8s or lower, latched the eios_finding_gen6 info of 1st 8 byte.
  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: latched_1st_8byte_eios_finding_gen6_PROC
    if(!rx_rst_n) begin
      latched_1st_8byte_eios_finding_gen6 <= #`TP '{default: 0};
      latched_1st_8byte_eieos_finding_gen6 <= #`TP '{default: 0};
    end
    else if(rx_sync_rst || !osfind_en || ((symbol_cnt + symbol_width) == 16) || symbol_cnt_adjust) begin
      latched_1st_8byte_eios_finding_gen6 <= #`TP '{default: 0};
      latched_1st_8byte_eieos_finding_gen6 <= #`TP '{default: 0};
    end
    else if(decoded_rxdatavalid) begin
      if ((symbol_cnt + symbol_width) == 8) begin
        latched_1st_8byte_eios_finding_gen6 <= #`TP eios_finding_gen6;
        latched_1st_8byte_eieos_finding_gen6 <= #`TP eieos_finding_gen6;
      end
    end
  end

// --------------------------------------------------------------------------------
//  Functions
// --------------------------------------------------------------------------------

// Check any 5byte of alinged 8byte are match
  function automatic logic any_of_5_match (
    logic [7:0] match_bitmap           // Mached OS bitmap for 8byte
  );    
    logic [2:0] count;                 // bit counter
    begin
      count = 3'b000;
      any_of_5_match = 0; 
      for(int ii = 0; ii < 8 ; ii++) begin
        if(match_bitmap[ii]) begin
          if(count == 3'h4) begin
            any_of_5_match = 1'b1;
          end
          else begin
            count = $bits(count)'(count + 3'b001);
            any_of_5_match = 1'b0;
          end
        end
      end
    end
  endfunction

// Check consecutive 5byte of alinged 8byte are match
  function automatic logic consecutive_5_match (
    logic [7:0] match_bitmap          // Mached OS bitmap for 8byte
    );
    begin
      if((&match_bitmap[0 +: 5])
      || (&match_bitmap[1 +: 5]) 
      || (&match_bitmap[2 +: 5]) 
      || (&match_bitmap[3 +: 5])) begin
         consecutive_5_match = 1'b1; 
      end
      else begin
         consecutive_5_match = 1'b0;
      end
    end
  endfunction

// --------------------------------------------------------------------------------
//  EIOS finding (for Gen6)
// --------------------------------------------------------------------------------

// Check matching for each byte 
  always_comb begin: comapre_eios_symbol_PROC
    eios_finding_gen6.match_bitmap = prev_eios_finding_gen6.match_bitmap;
    eios_finding_gen6.match_1st = prev_eios_finding_gen6.match_1st;

    // Flush the content
    // 1s,2s,4s: Store the value for first 8 byte. Flush the value on symbol 8
    // 8s or above: Flush in every cycle.
    if(symbol_cnt inside {0,8}) begin
      eios_finding_gen6.match_bitmap = $bits(eios_finding_gen6.match_bitmap)'(0);
      eios_finding_gen6.match_1st = $bits(eios_finding_gen6.match_1st)'(0);
    end
    for(int ii = 0; ii < PHY_NB; ii++) begin
      if(symbol_width > ii) begin
        if(((ii % BLOCK_INT_GEN6) == 0)
        && (decoded_rxstartblock[ii*2/BLOCK_INT_GEN6])
        && ((decoded_rxsyncheader[ii*2/BLOCK_INT_GEN6] == SYNC_HDR_OS) || poll_compliance_state)) begin   // 1st byte of DataBlock
        // If Ltssm is in Polling.Compliance, EIOS should be detected without OS syncheader
          eios_finding_gen6.match_1st[ii/BLOCK_INT_GEN6] = 1'b1;
        end
        if(ei_found[ii]) begin
          eios_finding_gen6.match_bitmap[ii + (LOG2_BLOCK_INT_GEN6)'(symbol_cnt)] = 1'b1;
        end
      end
    end
  end

// The number of match count (per 8Byte)
  always_comb begin: valid_eios_8byte_PROC
    for(int ii = 0; ii < OS_FIND_GEN6_WD; ii++) begin
        eios_finding_gen6.valid_sym_cnt_in_first_8byte[ii] = eios_finding_gen6.match_1st[ii] & any_of_5_match( eios_finding_gen6.match_bitmap[ii*BLOCK_INT_GEN6 +: BLOCK_INT_GEN6]);
    end
  end

// check (Symbol0 or 8) and 1st 8byte
  always_comb begin: raw_eios_found_gen6_PROC
    raw_eios_found_gen6 = '0;
  // temporary cahnge for HW test Start
  // temporary cahnge for HW test End
    if(symbol_width <= 8) begin // For 8s or below
        raw_eios_found_gen6[0] = latched_1st_8byte_eios_finding_gen6.valid_sym_cnt_in_first_8byte[0] 
                               & (in_datastream | eios_finding_gen6.match_bitmap[0] | latched_1st_8byte_eios_finding_gen6.match_bitmap[0]);
    end
  end

// --------------------------------------------------------------------------------
//  EIEOS finding (for Gen6)
// --------------------------------------------------------------------------------

// Expectd EIEOS value per byte
  always_comb begin: making_eieos_expectation_symbol_PROC
    exp_eieos = (symbol_cnt < 8) ? '0 : '1; // For 8s or lower
  end

  function automatic logic match_eieos_symbol (
    logic [7:0] data,
    logic       exp_eieos
  );
    begin
      if(exp_eieos == 0) begin
        match_eieos_symbol = (data == 8'h00);
      end
      else begin
        match_eieos_symbol = (data == 8'hFF);
      end
    end
  endfunction

  function automatic logic match_eieos_symbol_allowed_1b_mismatch (
    logic [7:0] data,
    logic       exp_eieos
  );
    begin
      if(exp_eieos == 0) begin
        match_eieos_symbol_allowed_1b_mismatch = (data inside {8'b0000_0000,
                                                               8'b0000_0001,
                                                               8'b0000_0010,
                                                               8'b0000_0100,
                                                               8'b0000_1000,
                                                               8'b0001_0000,
                                                               8'b0010_0000,
                                                               8'b0100_0000,
                                                               8'b1000_0000});
      end
      else begin
        match_eieos_symbol_allowed_1b_mismatch = (data inside {8'b1111_1111,
                                                               8'b1111_1110,
                                                               8'b1111_1101,
                                                               8'b1111_1011,
                                                               8'b1111_0111,
                                                               8'b1110_1111,
                                                               8'b1101_1111,
                                                               8'b1011_1111,
                                                               8'b0111_1111});
      end
    end
  endfunction

  function automatic logic match_eieos_8byte (
    logic [7:0] match_bitmap,
    logic       in_datastream
  );
    begin
      match_eieos_8byte = in_datastream ? any_of_5_match(match_bitmap) : consecutive_5_match(match_bitmap);
    end
  endfunction


// Check maching for each byte 
  always_comb begin: comapre_eieos_symbol_PROC
    eieos_finding_gen6.match_bitmap = prev_eieos_finding_gen6.match_bitmap;
    eieos_finding_gen6.match_bitmap_1b_mismatch = prev_eieos_finding_gen6.match_bitmap_1b_mismatch;
    eieos_finding_gen6.match_1st = prev_eieos_finding_gen6.match_1st;

    // Flush the content
    // 1s,2s,4s: Store the value for first 8 byte. Flush the value on symbol 8
    // 8s or above: Flush in every cycle.
    if(symbol_cnt inside {0,8}) begin
      eieos_finding_gen6.match_bitmap = $bits(eieos_finding_gen6.match_bitmap)'(0);
      eieos_finding_gen6.match_bitmap_1b_mismatch = $bits(eieos_finding_gen6.match_bitmap_1b_mismatch)'(0);
      eieos_finding_gen6.match_1st = $bits(eieos_finding_gen6.match_1st)'(0);
    end
    for(int ii = 0; ii < PHY_NB; ii++) begin
      if(symbol_width > ii) begin
        if(((ii % BLOCK_INT_GEN6) == 0)
          && (decoded_rxstartblock[ii*2/BLOCK_INT_GEN6])
          && (decoded_rxsyncheader[ii*2/BLOCK_INT_GEN6] == SYNC_HDR_OS)) begin   // 1st byte of DataBlock
          eieos_finding_gen6.match_1st[ii/BLOCK_INT_GEN6] = 1'b1;
        end
        eieos_finding_gen6.match_bitmap[ii + (LOG2_BLOCK_INT_GEN6)'(symbol_cnt)] = match_eieos_symbol(decoded_rxdata[ii], exp_eieos[ii]);
        eieos_finding_gen6.match_bitmap_1b_mismatch[ii + (LOG2_BLOCK_INT_GEN6)'(symbol_cnt)] = match_eieos_symbol_allowed_1b_mismatch(decoded_rxdata[ii], exp_eieos[ii]);
      end
    end
  end

// The number of match count (per 8Byte)
  always_comb begin: judge_eieos_match_8byte_PROC
    for(int ii = 0; ii < OS_FIND_GEN6_WD; ii++) begin
      eieos_finding_gen6.valid_sym_cnt_in_first_8byte[ii] = eieos_finding_gen6.match_1st[ii] & match_eieos_8byte(eieos_finding_gen6.match_bitmap[ii*BLOCK_INT_GEN6 +: BLOCK_INT_GEN6], in_datastream);
    end
  end

// check (Symbol0 or 8) and 1st 8byte
  always_comb begin: raw_eieos_found_gen6_PROC
    raw_eieos_found_gen6 = '0;
  // temporary cahnge for HW test Start
  // temporary cahnge for HW test End
    if(symbol_width <= 8) begin
        raw_eieos_found_gen6[0] = latched_1st_8byte_eieos_finding_gen6.valid_sym_cnt_in_first_8byte[0] 
                                 & (in_datastream | match_eieos_8byte(eieos_finding_gen6.match_bitmap[0 +: BLOCK_INT_GEN6], in_datastream))
                                 & (in_datastream | eieos_finding_gen6.match_bitmap_1b_mismatch[0] | latched_1st_8byte_eieos_finding_gen6.match_bitmap_1b_mismatch[0]);
    end
  end

// --------------------------------------------------------------------------------
//  SDSOS finding (for Gen6)
// --------------------------------------------------------------------------------

// Check matching for each byte 
  always_comb begin: comapre_sdsos_symbol_PROC
    sdsos_finding_gen6.match_bitmap = $bits(sdsos_finding_gen6.match_bitmap)'(0);
    sdsos_finding_gen6.match_1st = $bits(sdsos_finding_gen6.match_1st)'(0);

    for(int ii = 0; ii < PHY_NB; ii++) begin
      if(symbol_width > ii) begin
        if(((ii % BLOCK_INT_GEN6) == 0)
        && (decoded_rxstartblock[ii*2/BLOCK_INT_GEN6])
        && (decoded_rxsyncheader[ii*2/BLOCK_INT_GEN6] == SYNC_HDR_OS)) begin // 1st byte of DataBlock
          sdsos_finding_gen6.match_1st[ii/BLOCK_INT_GEN6] = 1'b1;
        end            
        if(sds_id_found[ii]) begin
          sdsos_finding_gen6.match_bitmap[ii] = 1'b1;
        end
      end
    end
  end

// Compare 4byte symbol are matched
  function automatic logic sds_4byte_match (
    logic [3:0] match_bitmap
  );
    begin
      sds_4byte_match = &match_bitmap;
    end
  endfunction

  always_comb begin: match_sds_4byte_PROC
    for(int ii = 0; ii < PHY_NB/4; ii++) begin
      sdsos_finding_gen6.good_sds_4byte[ii] = sds_4byte_match(sdsos_finding_gen6.match_bitmap[ii*4 +: 4]);
    end
  end

// Count how many 4byte symbol are matched
  function automatic logic [2:0] cnt_4byte_match (
    logic [7:0] match_bitmap        // maximum 32byte(2 OS) count for PIPE Width is greater than 32Byte. 
  );
    begin
      // To ease sinthesis timing
      case(match_bitmap[1:0])
        2'b00   : cnt_4byte_match = 3'h0;
        2'b01   : cnt_4byte_match = 3'h1;
        2'b10   : cnt_4byte_match = 3'h1;
        default : cnt_4byte_match = 3'h2;    // [1:0] = 2'b11
      endcase 
    end
  endfunction

// Count how many even 4byte are matched
function automatic logic [2:0] cnt_even_4byte_match ;
    input [7:0] match_bitmap ;        // maximum 32byte(2 OS) count for PIPE Width is greater than 32Byte. 
    input [5:0] symbol_cnt ;

  begin
      cnt_even_4byte_match = (symbol_cnt[2] == 0) ? // To check if it is the even 4-byte for 4s.
                             $bits(cnt_even_4byte_match)'(match_bitmap[0]
                                                        + match_bitmap[2]
                                                        + match_bitmap[4]
                                                        + match_bitmap[6])
                                                      : '0 ;
  end

endfunction

// Carry over OS to next cycle
  logic check_fin_sds;
  always_comb begin: carry_over_sds_PROC
    sdsos_finding_gen6.crry_over_cnt_symbol = '0;
    sdsos_finding_gen6.crry_over_cnt_any_good_4byte = '0;
    sdsos_finding_gen6.crry_over_cnt_even_good_4byte = '0;
    check_fin_sds = '0;

    if(prev_sdsos_finding_gen6.crry_over_cnt_symbol != '0) begin // carried over from previous cycle.
      if((prev_sdsos_finding_gen6.crry_over_cnt_symbol + symbol_width) < 32) begin   // carry over again
        sdsos_finding_gen6.crry_over_cnt_symbol = $bits(sdsos_finding_gen6.crry_over_cnt_symbol)'(prev_sdsos_finding_gen6.crry_over_cnt_symbol + symbol_width);
        sdsos_finding_gen6.crry_over_cnt_any_good_4byte = $bits(sdsos_finding_gen6.crry_over_cnt_any_good_4byte)'(prev_sdsos_finding_gen6.crry_over_cnt_any_good_4byte + cnt_4byte_match( 8'(sdsos_finding_gen6.good_sds_4byte)));
        sdsos_finding_gen6.crry_over_cnt_even_good_4byte = $bits(sdsos_finding_gen6.crry_over_cnt_even_good_4byte)'(prev_sdsos_finding_gen6.crry_over_cnt_even_good_4byte + cnt_even_4byte_match( 8'(sdsos_finding_gen6.good_sds_4byte), symbol_cnt));
      end
    end
    else begin // no carried over
      if(symbol_width <= 8) begin // For 4s, 8s
        if(|sdsos_finding_gen6.good_sds_4byte) begin
          if(sdsos_finding_gen6.match_1st[0]) begin 
            sdsos_finding_gen6.crry_over_cnt_symbol = $bits(sdsos_finding_gen6.crry_over_cnt_symbol)'(symbol_width); // 1st 8byte of SDS OS
          end
          else if(symbol_cnt < BLOCK_SYM_NUM) begin
            sdsos_finding_gen6.crry_over_cnt_symbol = $bits(sdsos_finding_gen6.crry_over_cnt_symbol)'(symbol_width + symbol_cnt);
          end
          sdsos_finding_gen6.crry_over_cnt_any_good_4byte = cnt_4byte_match(8'(sdsos_finding_gen6.good_sds_4byte));
          sdsos_finding_gen6.crry_over_cnt_even_good_4byte = cnt_even_4byte_match(8'(sdsos_finding_gen6.good_sds_4byte), symbol_cnt);
        end
      end
    end
  end


// Make raw_sdsos_found_gen6 : any four 4bytes are matching in 16byte*2 OS & two even 4byte are matching
  always_comb begin: raw_sds_found_gen6_PROC
    raw_sdsos_found_gen6 = '0;

    if(prev_sdsos_finding_gen6.crry_over_cnt_symbol != '0) begin // carried over from previous cycle.
      if((prev_sdsos_finding_gen6.crry_over_cnt_symbol + symbol_width) < 32) begin // carry over again
          raw_sdsos_found_gen6[0] = (prev_sdsos_finding_gen6.crry_over_cnt_any_good_4byte + cnt_4byte_match(8'(sdsos_finding_gen6.good_sds_4byte)) >= 4) // any four 4bytes are matching
                                  & (prev_sdsos_finding_gen6.crry_over_cnt_even_good_4byte + cnt_even_4byte_match(8'(sdsos_finding_gen6.good_sds_4byte), symbol_cnt) >= 2); // two even 4byte are matching
      end
      else begin // complete this cycle
        if(prev_sdsos_finding_gen6.crry_over_cnt_symbol == 6'd28) begin // Last 4byte in this cycle (only 4s)
          raw_sdsos_found_gen6[0] = (prev_sdsos_finding_gen6.crry_over_cnt_any_good_4byte + cnt_4byte_match(8'(sdsos_finding_gen6.good_sds_4byte)) >= 4) // any of four 4byte are matching
                                  & (prev_sdsos_finding_gen6.crry_over_cnt_even_good_4byte + cnt_even_4byte_match(8'(sdsos_finding_gen6.good_sds_4byte), symbol_cnt) >= 2); // two even 4byte are matching
        end
        else if(prev_sdsos_finding_gen6.crry_over_cnt_symbol == 6'd24) begin // Last 8byte in this cycle
          raw_sdsos_found_gen6[0] = (prev_sdsos_finding_gen6.crry_over_cnt_any_good_4byte + cnt_4byte_match(8'(sdsos_finding_gen6.good_sds_4byte[1:0])) >= 4) // any of four 4byte are matching
                                  & (prev_sdsos_finding_gen6.crry_over_cnt_even_good_4byte + cnt_even_4byte_match(8'(sdsos_finding_gen6.good_sds_4byte[1:0]), symbol_cnt) >= 2); // two even 4byte are matching
        end
      end
    end
  end


// --------------------------------------------------------------------------------
//  SKP finding (for Gen6)
// --------------------------------------------------------------------------------

// Check matching for each byte 
  always_comb begin: comapre_skpos_symbol_PROC
    skpos_finding_gen6.match_bitmap = prev_skpos_finding_gen6.match_bitmap;
    skpos_finding_gen6.match_bitmap_skpend = prev_skpos_finding_gen6.match_bitmap_skpend;
    skpos_finding_gen6.match_1st = prev_skpos_finding_gen6.match_1st;

    // Flush the content
    // 1s,2s,4s: Flush the value on each 8 byte
    // 8s or above: Flush in every cycle.
    if((LOG2_BLOCK_INT_GEN6)'(symbol_cnt) == 0) begin
      skpos_finding_gen6.match_bitmap = $bits(skpos_finding_gen6.match_bitmap)'(0);
      skpos_finding_gen6.match_bitmap_skpend = $bits(skpos_finding_gen6.match_bitmap_skpend)'(0);
      skpos_finding_gen6.match_1st = $bits(skpos_finding_gen6.match_1st)'(0);
    end
    for(int ii = 0; ii < PHY_NB; ii++) begin
      if(symbol_width > ii) begin
        if(((ii % BLOCK_INT_GEN6) == 0)
        && (decoded_rxstartblock[ii*2/BLOCK_INT_GEN6])
        && (decoded_rxsyncheader[ii*2/BLOCK_INT_GEN6] == SYNC_HDR_OS)) begin // 1st byte of DataBlock
          skpos_finding_gen6.match_1st[ii/BLOCK_INT_GEN6] = 1'b1;
        end            
        if(skp_id_found[ii]) begin
          skpos_finding_gen6.match_bitmap[ii + (LOG2_BLOCK_INT_GEN6)'(symbol_cnt)] = 1'b1;
        end
        if(skp_end_found[ii]) begin
          skpos_finding_gen6.match_bitmap_skpend[ii + (LOG2_BLOCK_INT_GEN6)'(symbol_cnt)] = 1'b1;
        end
      end
    end
  end

// The number of match count (per 8Byte)
  always_comb begin: valid_skp_8byte_PROC
    for(int ii = 0; ii < OS_FIND_GEN6_WD; ii++) begin
      skpos_finding_gen6.valid_sym_cnt_in_first_8byte[ii] = skpos_finding_gen6.match_1st[ii] & any_of_5_match(skpos_finding_gen6.match_bitmap[ii*BLOCK_INT_GEN6 +: BLOCK_INT_GEN6]);
      skpos_finding_gen6.valid_sym_cnt_skpend_8byte[ii] = any_of_5_match(skpos_finding_gen6.match_bitmap_skpend[ii*BLOCK_INT_GEN6 +: BLOCK_INT_GEN6]);
    end
  end

// Matching SKP OS condtions are met
  always_comb begin : find_skp_PROC
    skpos_finding_gen6.valid_find_skpos = 0;
    for(int ii = 0; ii < OS_FIND_GEN6_WD; ii++) begin
      if(ii == 0) begin // Last 8byte of previous cycle and current 1st 8byte case
        skpos_finding_gen6.valid_find_skpos[ii] = (skpos_finding_gen6.valid_sym_cnt_in_first_8byte[0]
                                                & (in_datastream | skpos_finding_gen6.match_bitmap[0] )) 
                                                || (prev_skpos_finding_gen6.valid_sym_cnt_in_first_8byte[OS_FIND_GEN6_WD - 1]
                                                & (in_datastream | skpos_finding_gen6.match_bitmap[0] | skpos_finding_gen6.match_bitmap_skpend[0] | prev_skpos_finding_gen6.match_bitmap[(OS_FIND_GEN6_WD - 1)*BLOCK_INT_GEN6]));
      end
    end
  end

// Carry over OS to next cycle
  logic check_fin_skp;
  always_comb begin: carry_over_skp_PROC
    skpos_finding_gen6.crry_over_cnt_symbol = '0;
    skpos_finding_gen6.crry_over_find_skpos = '0;
    check_fin_skp = '0;
    if(prev_skpos_finding_gen6.crry_over_cnt_symbol != '0) begin // carried over from previous cycle.
      if((prev_skpos_finding_gen6.crry_over_cnt_symbol + symbol_width) < 'd56
      ) begin // carry over again
        skpos_finding_gen6.crry_over_cnt_symbol = skpos_finding_gen6.valid_sym_cnt_skpend_8byte[OS_FIND_GEN6_WD-1] ? 6'd48
                                                      : $bits(skpos_finding_gen6.crry_over_cnt_symbol)'(prev_skpos_finding_gen6.crry_over_cnt_symbol + symbol_width);
        skpos_finding_gen6.crry_over_find_skpos = prev_skpos_finding_gen6.crry_over_find_skpos | skpos_finding_gen6.valid_find_skpos[0];
      end
    end
    else begin // no carried over
      if(symbol_width <= 8) begin // For 4s, 8s
        if(skpos_finding_gen6.valid_find_skpos[0]) begin // find 1st 8byte
          skpos_finding_gen6.crry_over_cnt_symbol = skpos_finding_gen6.valid_sym_cnt_skpend_8byte[OS_FIND_GEN6_WD-1] ? 6'd48 :
                                                    $bits(skpos_finding_gen6.crry_over_cnt_symbol)'(symbol_width + symbol_cnt);
          skpos_finding_gen6.crry_over_find_skpos = |skpos_finding_gen6.valid_find_skpos;
        end       
      end
    end
  end

  assign skpos_last_symbol  = |raw_skpos_found_gen6;
  assign skp_end_found_gen6 = skpos_found && !skpos_last_symbol && |skpos_finding_gen6.valid_sym_cnt_skpend_8byte;

  logic  latched_skp_end_found_gen6;
  assign err_skp_wo_skp_end = skpos_last_symbol && !latched_skp_end_found_gen6 && in_datastream;

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: latched_skp_end_found_gen6_PROC
    if(!rx_rst_n) begin
      latched_skp_end_found_gen6    <= #`TP '0;
    end
    else if(skpos_last_symbol || (symbol_cnt == 0)) begin
      latched_skp_end_found_gen6    <= #`TP '0;
    end
    else if(skp_end_found_gen6) begin
      latched_skp_end_found_gen6    <= #`TP 1'b1;
    end
  end

// Make raw_skpos_found_gen6 :
// spyglass disable_block AlwaysCombExhaustive-ML
// SMD: Not all conditions are covered for the combinational logic.
// SJ: A default value is defined to avoid a latch.
  always_comb begin: raw_skpos_found_gen6_PROC
    raw_skpos_found_gen6 = '0;

    if(prev_skpos_finding_gen6.crry_over_cnt_symbol != '0) begin // carried over from previous cycle.
      if((prev_skpos_finding_gen6.crry_over_cnt_symbol + symbol_width) < 'd56) begin // carry over again
        raw_skpos_found_gen6[0] = 0;
      end
      else begin
        raw_skpos_found_gen6[0] = prev_skpos_finding_gen6.crry_over_find_skpos | skpos_finding_gen6.valid_find_skpos[0];
      end
    end
  end
// spyglass enable_block AlwaysCombExhaustive-ML

// --------------------------------------------------------------------------------
//  Detected Corrected OS for Flit Logging Capability
// --------------------------------------------------------------------------------
  logic eieos_corrected;
  logic eios_corrected;
  logic sdsos_corrected;
  logic detected_sdsos_corrected;

  assign eieos_corrected = eieos_found && !(&eieos_finding_gen6.match_bitmap && &latched_1st_8byte_eieos_finding_gen6.match_bitmap) && ((symbol_cnt + symbol_width) == 16);
  assign eios_corrected  = eios_found && !(&eios_finding_gen6.match_bitmap && &latched_1st_8byte_eios_finding_gen6.match_bitmap) && ((symbol_cnt + symbol_width) == 16);
  assign sdsos_corrected = sdsos_found && !(&sdsos_finding_gen6.match_bitmap && &prev_sdsos_finding_gen6.match_bitmap) && ~detected_sdsos_corrected;

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: detected_sdsos_corrected_PROC
    if(!rx_rst_n) begin
      detected_sdsos_corrected <= #`TP '0;
    end
    else if( ~sdsos_found ) begin
      detected_sdsos_corrected <= #`TP '0;
    end
    else if(sdsos_corrected) begin
      detected_sdsos_corrected <= #`TP 1'b1;
    end
  end


  typedef struct packed {
    logic       en;
    logic       det;
    logic [2:0] cnt;
  }  skpos_corrected_find_t;

  logic skpos_corrected;
  skpos_corrected_find_t skpos_corrected_found, prev_skpos_corrected_found;

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: prev_skpos_corrected_found_PROC
    if(!rx_rst_n) begin
      prev_skpos_corrected_found <= #`TP '{default: 0};
    end
    else if(rx_sync_rst || !osfind_en) begin
      prev_skpos_corrected_found <= #`TP '{default: 0};
    end
    else if(decoded_rxdatavalid) begin
      prev_skpos_corrected_found <= #`TP skpos_corrected_found;
    end
  end

// spyglass disable_block AlwaysCombExhaustive-ML
// SMD: Not all conditions are covered for the combinational logic.
// SJ: A default value is defined to avoid a latch.
  always_comb begin: skpos_corrected_PROC
    skpos_corrected = 1'h0;
    skpos_corrected_found = prev_skpos_corrected_found;
    if(decoded_rxstartblock) begin
      skpos_corrected_found  = '0;
      if(decoded_rxsyncheader == SYNC_HDR_OS) begin    // 1st 8byte of OS
        skpos_corrected_found.en  = |skpos_finding_gen6.valid_sym_cnt_in_first_8byte ;    // Check if any 5byte match in 1st 8byte
      end
    end
    
    if( skpos_corrected_found.en ) begin
        if(  skp_end_found_gen6 && ~(&skpos_finding_gen6.match_bitmap_skpend) ) skpos_corrected_found.det = 1'b1 ;   // Not all 8byte are mached to SKP END
        if( ~skp_end_found_gen6 && ~(&skpos_finding_gen6.match_bitmap)        ) skpos_corrected_found.det = 1'b1 ;   // Not all 8byte are mached to SKP
    end
    if(skpos_corrected_found.cnt == 5 || skp_end_found_gen6) begin
      skpos_corrected = skpos_found & skpos_corrected_found.det;
      skpos_corrected_found = '0;
    end
    if(skpos_corrected_found.en)begin
      skpos_corrected_found.cnt = $bits(skpos_corrected_found.cnt)'(skpos_corrected_found.cnt + 1);
    end
  end
// spyglass enable_block AlwaysCombExhaustive-ML

  assign os_corrected = eieos_corrected || eios_corrected || sdsos_corrected || skpos_corrected;

endmodule: serdes_pipe_rx_1b1b_osfind
