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
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_128b130b_osfind.sv#14 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side 128b/130b Ordered Set find module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_128b130b_osfind

  import serdes_pipe_pkg::*;
(
  // ------------- input -----------------
  input logic                    rx_clk,
  input logic                    rx_rst_n,
  input logic                    rx_sync_rst,
  input logic [PHY_SYM_WD-1:0]   symbol_width,
  input logic [RATE_WD-1:0]      pipe_rate,
  input logic                    sync_hdr_bypass_en,
  input logic                    flit_mode_enable,
  input logic                    block_aligned,
  input pipe_data128b_t          decoded_rxdata,
  input logic                    decoded_rxdatavalid,
  input logic [PHY_RXSB_WD-1:0]  decoded_rxstartblock,
  input pipe_syncheader_t        decoded_rxsyncheader,
  // ------------- output ----------------
  output logic                   sdsos_found,
  output logic                   skpos_found,
  output logic                   eieos_found,
  output logic                   eieos_found_for_deskew,
  output logic                   eios_found,
  output os_t [PHY_RXSB_WD-1:0]  os_found,
  output logic                   err_undef_syncheader,
  output logic                   err_undef_skp
);

// --------------------------------------------------------------------------------
//  Common internal type
// --------------------------------------------------------------------------------
  localparam OS_FIND_LOOP_NUM  = PHY_RXSB_WD ;
  localparam OS_FIND_SERCH_NUM = (PHY_NB >= 4) ? 4 : PHY_NB ;
  localparam MAX_SKPOS_BYTE = 24;

  typedef struct packed {
    logic                              en;
    logic [$clog2(BLOCK_SYM_NUM)-1:0]  cnt;
  }  osfind_t;

  typedef struct packed {
    logic                              en;
    logic [$clog2(MAX_SKPOS_BYTE)-1:0] cnt;
  }  skposfind_t;

// --------------------------------------------------------------------------------
//  Common internal signal
// --------------------------------------------------------------------------------
  logic [SYM_WD-1:0]  skp_id;

  always_comb begin: skp_id_PROC
    case(pipe_rate)
      `GEN5_RATE: skp_id = SYM_GEN5_SKP;
      default: skp_id = SYM_GEN3_SKP;
    endcase
  end

  logic [SYM_WD-1:0]  sds_body;

  always_comb begin: sds_body_PROC
    case(pipe_rate)
      `GEN5_RATE: sds_body = SYM_GEN5_SDS_BODY;
      default: sds_body = SYM_GEN3_SDS_BODY;
    endcase
  end

  logic  osfind_en;
  assign osfind_en = block_aligned;

// --------------------------------------------------------------------------------
//  Create os_found signal
// --------------------------------------------------------------------------------
  logic [PHY_RXSB_WD-1:0] skp_det, skp_end_det, ei_det, eie_det, sds_det;

  always_comb begin: os_found_PROC
    for(int i = 0; i < OS_FIND_LOOP_NUM; i++) begin
      case({skp_det[i], skp_end_det[i], ei_det[i], eie_det[i], sds_det[i]})
        5'b10000: os_found[i] = SKP;
        5'b11000: os_found[i] = SKP_END;
        5'b00100: os_found[i] = EIOS;
        5'b00010: os_found[i] = EIEOS;
        5'b00001: os_found[i] = SDS;
         default: os_found[i] = NONE;   
      endcase
    end
  end

// --------------------------------------------------------------------------------
//  Undefined Syncheader error detection
// --------------------------------------------------------------------------------
  logic  raw_err_undef_syncheader;

  always_comb begin: err_undef_syncheader_PROC
    err_undef_syncheader = 1'h0;
    if(osfind_en) begin
      if(decoded_rxdatavalid) begin
        err_undef_syncheader = raw_err_undef_syncheader;
      end
    end
  end

  always_comb begin: raw_err_undef_syncheader_PROC
    raw_err_undef_syncheader = 1'h0;
    for(int i = 0; i < PHY_RXSB_WD; i++) begin
      if(decoded_rxstartblock[i]) begin
        if(!(decoded_rxsyncheader[i] inside {SYNC_HDR_OS, SYNC_HDR_DATA})) begin
          raw_err_undef_syncheader = 1'h1;
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  Undefined SKP error detection
// --------------------------------------------------------------------------------
  logic  raw_err_undef_skp;

  always_comb begin: err_undef_skp_PROC
    err_undef_skp = 1'h0;
    if(osfind_en) begin
      if(decoded_rxdatavalid) begin
        err_undef_skp = raw_err_undef_skp;
      end
    end
  end

// --------------------------------------------------------------------------------
//  OS symbol decoding
// --------------------------------------------------------------------------------
  logic [PHY_NB-1:0] skp_id_found, skp_end_found;
  logic [PHY_NB-1:0] ei_found;
  logic [PHY_NB-1:0] sds_id_found, sds_body_found;

  always_comb begin: skp_id_found_PROC
    skp_id_found = '0;
    skp_end_found = '0;
    ei_found = '0;
    sds_id_found = '0;
    sds_body_found = '0;
    for(int i = 0; i < PHY_NB; i++) begin
      skp_id_found[i] = (decoded_rxdata[i] == skp_id);
      case(pipe_rate)
        RATE_WD'(`GEN3_RATE): skp_end_found[i] = (decoded_rxdata[i] == SYM_SKP_END);
        default: skp_end_found[i] = (decoded_rxdata[i] inside {SYM_SKP_END, SYM_SKP_END_CTL});
      endcase
      if(flit_mode_enable) begin
        skp_end_found[i] = decoded_rxdata[i] inside {SYM_SKP_END, SYM_SKP_END_CTL};
      end
      ei_found[i] = (decoded_rxdata[i] == SYM_EI) ;
      sds_id_found[i] = (decoded_rxdata[i] == SYM_SDS_ID);
      sds_body_found[i] = (decoded_rxdata[i] == sds_body);
    end
  end

// --------------------------------------------------------------------------------
//  SKP error finding
// --------------------------------------------------------------------------------
  logic  skp_err_finding, prev_skp_err_finding;
  logic [$clog2(BLOCK_INT)-1:0]  skp_sym_cnt;

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: prev_skp_err_finding_PROC
    if(!rx_rst_n) begin
      prev_skp_err_finding <= #`TP 1'h0;
    end
    else if(rx_sync_rst || !osfind_en) begin
      prev_skp_err_finding <= #`TP 1'h0;
    end
    else if(decoded_rxdatavalid) begin
      prev_skp_err_finding <= #`TP skp_err_finding;
    end
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: skp_sym_cnt_PROC
    if(!rx_rst_n) begin
      skp_sym_cnt <= #`TP '0;
    end
    else if(rx_sync_rst || !osfind_en) begin
      skp_sym_cnt <= #`TP '0;
    end
    else if(symbol_width < BLOCK_INT) begin
      if(decoded_rxdatavalid) begin
        if(decoded_rxstartblock[0]) begin
          skp_sym_cnt <= #`TP $bits(skp_sym_cnt)'(BLOCK_INT - symbol_width);
        end
        else begin
          skp_sym_cnt <= #`TP $bits(skp_sym_cnt)'(skp_sym_cnt - symbol_width);
        end
      end
    end
  end

  always_comb begin: raw_err_undef_skp_PROC
    raw_err_undef_skp = 1'h0;
    skp_err_finding = prev_skp_err_finding;
    for(int i = 0; i < PHY_128B130B_NB; i++) begin
      if(symbol_width > i) begin
        if((i % BLOCK_INT) == 0) begin
          if(decoded_rxstartblock[i/BLOCK_INT]) begin
            skp_err_finding = 1'h0;
            if((decoded_rxsyncheader[i/BLOCK_INT] == SYNC_HDR_OS) && skp_id_found[i]) begin
              skp_err_finding = 1'h1;
            end
          end
          else if((skp_sym_cnt == '0) && skp_end_found[i]) begin
            skp_err_finding = 1'h0;
          end
        end
        if(skp_err_finding && !skp_id_found[i]) begin
          raw_err_undef_skp = 1'h1;
          skp_err_finding = 1'h0;
        end
      end
    end
  end


// --------------------------------------------------------------------------------
//  OS finding
// --------------------------------------------------------------------------------
  logic  raw_eios_found;
  logic  raw_eieos_found;
  logic  raw_skpos_found;
  logic  raw_sdsos_found;

  always_comb begin: eios_found_PROC
    eios_found = 1'h0;
    eieos_found = 1'h0;
    skpos_found = 1'h0;
    sdsos_found = 1'h0;
    if(osfind_en) begin
      if(decoded_rxdatavalid) begin
        eios_found = raw_eios_found;
        eieos_found = raw_eieos_found;
        skpos_found = raw_skpos_found;
        sdsos_found = raw_sdsos_found;
      end
    end
  end

  osfind_t    eios_finding, prev_eios_finding;
  osfind_t    eieos_finding, prev_eieos_finding;
  osfind_t    sdsos_finding, prev_sdsos_finding;
  skposfind_t skpos_finding, prev_skpos_finding;

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: prev_eios_finding_PROC
    if(!rx_rst_n) begin
      prev_eios_finding <= #`TP '0;
      prev_eieos_finding <= #`TP '0;
      prev_skpos_finding <= #`TP '0;
      prev_sdsos_finding <= #`TP '0;
    end
    else if(rx_sync_rst || !osfind_en) begin
      prev_eios_finding <= #`TP '0;
      prev_eieos_finding <= #`TP '0;
      prev_skpos_finding <= #`TP '0;
      prev_sdsos_finding <= #`TP '0;
    end
    else if(decoded_rxdatavalid) begin
      prev_eios_finding <= #`TP eios_finding;
      prev_eieos_finding <= #`TP eieos_finding;
      prev_skpos_finding <= #`TP skpos_finding;
      prev_sdsos_finding <= #`TP sdsos_finding;
    end
  end

    logic [$clog2(BLOCK_SYM_NUM)-1:0]  os_cnt_last;
    logic [$clog2(BLOCK_SYM_NUM)-1:0]  os_cnt_up;

    always_comb begin
      case( symbol_width ) 
        $bits(symbol_width)'( 1 ) : os_cnt_last = BLOCK_SYM_NUM - 1 ;    // 1s
        $bits(symbol_width)'( 2 ) : os_cnt_last = BLOCK_SYM_NUM - 2 ;    // 2s
        default                   : os_cnt_last = BLOCK_SYM_NUM - 4 ;    // 4s/8/16s
      endcase
    end

    always_comb begin
      case( symbol_width ) 
        $bits(symbol_width)'( 1 ) : os_cnt_up = 1 ;    // 1s
        $bits(symbol_width)'( 2 ) : os_cnt_up = 2 ;    // 2s
        default                   : os_cnt_up = 4 ;    // 4s/8/16s
      endcase
    end

// --------------------------------------------------------------------------------
//  EIOS finding
// --------------------------------------------------------------------------------
  logic [OS_FIND_SERCH_NUM-1:0] eios_4byte_found ;
  
// spyglass disable_block AlwaysCombExhaustive-ML
// SMD: Not all conditions are covered for the combinational logic.
// SJ: A default value is defined to avoid a latch.
  always_comb begin: raw_eios_found_PROC
    raw_eios_found = 1'h0;
    eios_finding = prev_eios_finding;
    ei_det = '0;
    for(int ii = 0; ii < OS_FIND_LOOP_NUM; ii++) begin
      if(symbol_width > ii*4) begin
        if(decoded_rxstartblock[ii]) begin
          eios_finding = '0;
          if(decoded_rxsyncheader[ii] == SYNC_HDR_OS) begin
            eios_finding.en = 1'h1;
          end
        end

        // Compare Data and EI OS value
        for(int jj = 0; jj < OS_FIND_SERCH_NUM; jj++) begin
            eios_4byte_found[jj] = ei_found[ii*4 + jj] | (symbol_width <= (ii*4 + jj) ) ;
        end        

        if(eios_finding.cnt < 4) begin
          if( !( &eios_4byte_found ) ) begin
            eios_finding = '0;
          end
        end
        if(eios_finding.en) begin
          ei_det[ii] = 1;
          if(eios_finding.cnt == os_cnt_last) begin
            raw_eios_found = 1'h1;
            eios_finding = '0;
          end
          else begin
            eios_finding.cnt = $bits(eios_finding.cnt)'(eios_finding.cnt + os_cnt_up);
          end
        end
      end
    end
  end
// spyglass enable_block AlwaysCombExhaustive-ML

// --------------------------------------------------------------------------------
//  EIEOS finding
// --------------------------------------------------------------------------------
    logic [31:0]                  exp_eieos_4byte ;
    logic [OS_FIND_SERCH_NUM-1:0] eie_found;
    

// spyglass disable_block AlwaysCombExhaustive-ML
// SMD: Not all conditions are covered for the combinational logic.
// SJ: A default value is defined to avoid a latch.
  always_comb begin: raw_eieos_found_PROC
    raw_eieos_found = 1'h0;
    exp_eieos_4byte = '0 ;
    eie_found = '0 ;
    eieos_finding = prev_eieos_finding;
    eie_det = '0;
    for(int ii = 0; ii < OS_FIND_LOOP_NUM; ii++) begin
      if(symbol_width > ii*4) begin
        if(decoded_rxstartblock[ii]) begin
          eieos_finding = '0;
          if(decoded_rxsyncheader[ii] == SYNC_HDR_OS) begin
            eieos_finding.en = 1'h1;
          end
        end

        // EIEOS Value
        // Gen3 : 128'hFF00_FF00_FF00_FF00_FF00_FF00_FF00_FF00
        // Gen4 : 128'hFFFF_0000_FFFF_0000_FFFF_0000_FFFF_0000
        // Gen5 : 128'hFFFF_FFFF_0000_0000_FFFF_FFFF_0000_0000
          case( pipe_rate ) 

              RATE_WD'(`GEN3_RATE) : exp_eieos_4byte = (eieos_finding.cnt[0]   == 1'b0 )  ? { 8'hFF , 8'h00 , 8'hFF , 8'h00 }           // support from 1s to 16s
                                                                                          : { 8'h00 , 8'hFF , 8'h00 , 8'hFF } ;
              RATE_WD'(`GEN4_RATE) : exp_eieos_4byte = (eieos_finding.cnt[1]   == 1'b0 )  ? { 8'hFF , 8'hFF , 8'h00 , 8'h00 }           // support 2s or wider. Not support 1s
                                                                                          : { 8'h00 , 8'h00 , 8'hFF , 8'hFF } ;
              RATE_WD'(`GEN5_RATE) : exp_eieos_4byte = (eieos_finding.cnt[2:1] == 2'b00 ) ? { 8'h00 , 8'h00 , 8'h00 , 8'h00 }           // support 2s or wider. Not support 1s
                                                     : (eieos_finding.cnt[2:1] == 2'b01 ) ? { 8'hFF , 8'hFF , 8'h00 , 8'h00 }  
                                                     : (eieos_finding.cnt[2:1] == 2'b10 ) ? { 8'hFF , 8'hFF , 8'hFF , 8'hFF }  
                                                                                          : { 8'h00 , 8'h00 , 8'hFF , 8'hFF } ;
              default    : exp_eieos_4byte = '0 ;
          endcase

          // Compare Data and EIE OS value
        for(int jj = 0; jj < OS_FIND_SERCH_NUM; jj++) begin
            eie_found[jj] = (decoded_rxdata[ii*4 + jj] == exp_eieos_4byte[jj*SYM_WD +: SYM_WD]) | (symbol_width <= (ii*4 + jj) ) ;
        end

        if( !( &eie_found ) ) begin 
            eieos_finding = '0;
        end
        if(eieos_finding.en) begin
          eie_det[ii] = 1;
          if(eieos_finding.cnt == os_cnt_last) begin
            raw_eieos_found = 1'h1;
            eieos_finding = '0;
          end
          else begin
            eieos_finding.cnt = $bits(eieos_finding.cnt)'(eieos_finding.cnt + os_cnt_up);
          end
        end
      end
    end
  end
// spyglass enable_block AlwaysCombExhaustive-ML

// --------------------------------------------------------------------------------
//  EIEOSQ finding for drift buffer deskew
// --------------------------------------------------------------------------------

  logic [$clog2(BLOCK_SYM_NUM+1)-1:0]  symbol_cnt, next_symbol_cnt;
  logic                                symbol_cnt_expired;
  logic                                pre_eieos_found_d;
  assign next_symbol_cnt = $bits(next_symbol_cnt)'(symbol_cnt + symbol_width);
  assign symbol_cnt_expired = (next_symbol_cnt == $bits(next_symbol_cnt)'(BLOCK_SYM_NUM));

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: symbol_cnt_PROC
    if(!rx_rst_n) begin
      symbol_cnt <= #`TP '0;
    end
    else if(rx_sync_rst) begin
      symbol_cnt <= #`TP '0;
    end
    else if(pre_eieos_found_d) begin
      symbol_cnt <= #`TP (symbol_cnt_expired) ? '0 : (decoded_rxdatavalid) ? next_symbol_cnt : symbol_cnt;
    end
    else begin
      symbol_cnt <= #`TP '0;
    end
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: pre_eieos_found_d_PROC
    if(!rx_rst_n) begin
      pre_eieos_found_d <= #`TP 1'h0;
    end
    else if(rx_sync_rst) begin
      pre_eieos_found_d <= #`TP 1'h0;
    end
    else if(symbol_cnt_expired) begin
      pre_eieos_found_d <= #`TP 1'b0;
    end
    else if(raw_eieos_found) begin
      pre_eieos_found_d <= #`TP 1'b1;
    end
  end

  always_comb begin: eieos_found_for_deskew_PROC
    eieos_found_for_deskew = '0;
    if(osfind_en) begin
      if(decoded_rxdatavalid) begin
        eieos_found_for_deskew = raw_eieos_found;
        if(pipe_rate == RATE_WD'(`GEN5_RATE)) begin
          eieos_found_for_deskew &= pre_eieos_found_d;
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  SDSOS finding
// --------------------------------------------------------------------------------
    logic [31:0]                   exp_sdsos_4byte ;
    logic [OS_FIND_SERCH_NUM-1:0]  sds_found;
    
// spyglass disable_block AlwaysCombExhaustive-ML
// SMD: Not all conditions are covered for the combinational logic.
// SJ: A default value is defined to avoid a latch.
  always_comb begin: raw_sdsos_found_PROC
    raw_sdsos_found = 1'h0;
    exp_sdsos_4byte = '0 ;
    sds_found       = '0 ;
    sds_det         = '0 ;
    sdsos_finding = prev_sdsos_finding;
    for(int ii = 0; ii < OS_FIND_LOOP_NUM; ii++) begin
      if(symbol_width > ii*4) begin
        if(decoded_rxstartblock[ii]) begin
          sdsos_finding = '0;
          if(decoded_rxsyncheader[ii] == SYNC_HDR_OS) begin
            sdsos_finding.en = 1'h1;
          end
        end

        // SDSOS Value
        // Gen3/4 : { 15{8'h55} , 8'hE1 } 
        // Gen5   : { 15{8'h87} , 8'hE1 } 
        exp_sdsos_4byte = (sdsos_finding.cnt == '0 )  ? { sds_body , sds_body , sds_body , SYM_SDS_ID }
                                                      : { sds_body , sds_body , sds_body , sds_body   } ;
      
       // Compare Data and SDS OS value
        for(int jj = 0; jj < OS_FIND_SERCH_NUM; jj++) begin
           sds_found[jj] = (decoded_rxdata[ii*4 + jj] == exp_sdsos_4byte[jj*SYM_WD +: SYM_WD]) | (symbol_width <= (ii*4 + jj) ) ;
        end

        if(!( &sds_found )) begin
            sdsos_finding = '0;
        end
        if(sdsos_finding.en) begin
          sds_det[ii] = 1;
          if(sdsos_finding.cnt == os_cnt_last) begin
            raw_sdsos_found = 1'h1;
            sdsos_finding = '0;
          end
          else begin
            sdsos_finding.cnt = $bits(sdsos_finding.cnt)'(sdsos_finding.cnt + os_cnt_up);
          end
        end
      end
    end
  end
// spyglass enable_block AlwaysCombExhaustive-ML

// --------------------------------------------------------------------------------
//  SKPOS finding
// --------------------------------------------------------------------------------

    logic [$clog2(MAX_SKPOS_BYTE)-1:0]  skpos_cnt_last;

    always_comb begin
      case( symbol_width ) 
        $bits(symbol_width)'( 1 ) : skpos_cnt_last = MAX_SKPOS_BYTE - 1 ;    // 1s
        $bits(symbol_width)'( 2 ) : skpos_cnt_last = MAX_SKPOS_BYTE - 2 ;    // 2s
        default                   : skpos_cnt_last = MAX_SKPOS_BYTE - 4 ;    // 4s/8/16s
      endcase
    end

    logic [OS_FIND_SERCH_NUM-1:0]   skp_id_4byte_found;

// spyglass disable_block AlwaysCombExhaustive-ML
// SMD: Not all conditions are covered for the combinational logic.
// SJ: A default value is defined to avoid a latch.
  always_comb begin: raw_skpos_found_PROC
    raw_skpos_found = 1'h0;
    skp_id_4byte_found = '0;
    skpos_finding = prev_skpos_finding;
    skp_det = '0;
    skp_end_det = '0;
    for(int ii = 0; ii < OS_FIND_LOOP_NUM; ii++) begin
      if(symbol_width > ii*4) begin
        if(decoded_rxstartblock[ii]) begin
          skpos_finding = '0;
          if(decoded_rxsyncheader[ii] == SYNC_HDR_OS) begin
            skpos_finding.en = 1'h1;
          end
        end

        // Compare Data and SKP OS value
        for(int jj = 0; jj < OS_FIND_SERCH_NUM; jj++) begin
            skp_id_4byte_found[jj] = skp_id_found[ii*4 + jj] | (symbol_width <= (ii*4 + jj) ) ;
        end

        // SKP OS length is always 16 bytes when CXL syncheader bypass mode is enabled
        if(sync_hdr_bypass_en) begin
          if(skpos_finding.cnt < 12) begin
            if( !( &skp_id_4byte_found ) ) begin
              skpos_finding = '0;
            end
          end
          else if(skpos_finding.cnt == 12) begin
            if(!skp_end_found[ii*4]) begin
              skpos_finding = '0;
            end
          end
          if(skpos_finding.en) begin
            skp_det[ii] = 1;
            if(skpos_finding.cnt == 12) begin
              skp_end_det[ii] = 1;
            end             
            if(skpos_finding.cnt == $bits(skpos_finding.cnt)'(os_cnt_last)) begin
              raw_skpos_found = 1'h1;
              skpos_finding = '0;
            end
            else begin
              skpos_finding.cnt = $bits(skpos_finding.cnt)'(skpos_finding.cnt + os_cnt_up);
            end
          end
        end else
        begin
          if( !( &skp_id_4byte_found ) ) begin
            if(decoded_rxstartblock[ii]) begin
              skpos_finding = '0;
            end
            else if(!(skpos_finding.cnt[1:0] == '0 && skp_end_found[ii*4])) begin
              skpos_finding = '0;
            end
          end
          if(skpos_finding.en) begin
            skp_det[ii] = 1;
            if(skp_end_found[ii*4]) begin
              skp_end_det[ii] = 1;
            end
            skpos_finding.cnt = $bits(skpos_finding.cnt)'(skpos_finding.cnt + os_cnt_up);
          end
        end
      end
    end
  end
// spyglass enable_block AlwaysCombExhaustive-ML



endmodule: serdes_pipe_rx_128b130b_osfind
