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
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #18 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_estore.sv#18 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side elastic buffer module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_estore

  import serdes_pipe_pkg::*;
(
  // ---------- input (clk) --------------
  input logic                     clk,
  input logic                     rst_n,
  input logic                     estore_sync_rst,
  input logic                     sync_hdr_bypass_en,
  input logic                     encdec_8b10b,
  input logic [PHY_SYM_WD-1:0]    symbol_width,
  input logic [PHY_RAW_WD-1:0]    raw_width,
  input logic [RATE_WD-1:0]       pipe_rate,
  input logic [WIDTH_WD-1:0]      pipe_width,
  input logic                     pipe_srisen,
  input logic                     pipe_loopback_slave,
  input logic                     pipe_elasticbuffermode,
  // ---------- input (rx_clk) -----------
  input logic                     rx_clk,
  input logic                     rx_rst_n,
  input logic                     estore_rx_sync_rst,
  input logic                     drift_buffer_en,
  input logic                     encdec_8b10b_sync2rx,
  input logic [PHY_SYM_WD-1:0]    symbol_width_sync2rx,
  input logic [RATE_WD-1:0]       pipe_rate_sync2rx,
  input logic [WIDTH_WD-1:0]      pipe_width_sync2rx,
  input logic                     pipe_rxvalid,
  input logic                     symbol_locked,
  input pipe_data10b_t            locked_rxdata,
  input logic                     block_aligned,
  input pipe_data128b_t           decoded_rxdata,
  input logic                     decoded_rxdatavalid,
  input logic [PHY_RXSB_WD-1:0]   decoded_rxstartblock,
  input pipe_syncheader_t         decoded_rxsyncheader,
  input os_t [PHY_RXSB_WD-1:0]    decoded_os_found,
  input logic                     err_undef_skp,
  input logic                     osfind_os_corrected,
  // ---------- output (clk) -------------
  output logic                    estore_rdvalid,
  output pipe_data_t              estore_rddata,
  output logic                    estore_rddatavalid,
  output logic                    estore_mode,
  output logic [PHY_RXSB_WD-1:0]  estore_rxstartblock,
  output pipe_syncheader_t        estore_rxsyncheader,
  output os_t [PHY_RXSB_WD-1:0]   estore_os_found,
  output logic                    err_128b130b_decode,
  output logic                    estore_os_corrected,
  output logic                    sts_estore_skp_add,
  output logic                    sts_estore_skp_rem,
  output logic                    err_estore_overflow,
  output logic                    err_estore_underflow
);

// --------------------------------------------------------------------------------
//  Common internal parameter / type / function
// --------------------------------------------------------------------------------
  localparam int  DEPTH             = `CX_EBUF_DEPTH;
  localparam int  ADDR_WD           = $clog2(DEPTH);
  localparam int  MAX_SYNC_DELAY    = SYNC_TYPE + 2;
  localparam int  PTR_OFFSET        = ((2 ** ADDR_WD) - DEPTH) / 2;
  localparam int  PREF_8B10B_NUM    = get_pref_num(PHY_SYM_WD'(PHY_8B10B_NB), 1'h1 , 1'b0 );
  localparam int  PREF_128B130B_NUM = get_pref_num(PHY_SYM_WD'(PHY_128B130B_NB), (`CX_GEN3_SPEED_VALUE == 0) , 1'b0 );
  localparam int  PREF_NUM          = get_pref_num(PHY_SYM_WD'(PHY_NB), (`CX_GEN3_SPEED_VALUE == 0) , (`CX_GEN6_SPEED_VALUE == 1) );
  localparam int  SB_CNT_WD         = $clog2(((SYM_WD * PHY_NB) / SYNC_HDR_WD) + PHY_RXSB_WD + 1);
  localparam int  BLOCK_NUM         = (PHY_128B130B_NB > BLOCK_INT) ? ((PHY_128B130B_NB * 2) / BLOCK_INT) : 2;
  localparam int  BLOCK_NUM_GEN6    = (PHY_NB > BLOCK_INT_GEN6) ? ((PHY_NB * 2) / BLOCK_INT_GEN6) : 2;
  localparam int  LOG2_PHY_NB       = $clog2(PHY_NB) ;    
  localparam int  WR_WD             = PHY_NB ;
  localparam int  RD_WD             = PHY_NB+PREF_NUM ;

  // This "NUM_WD_1" and "NUM_WD_2" are there to avoid the Spyglass ImproperRangeIndex-ML 
  localparam int  NUM_WD_1        = $clog2(PHY_8B10B_NB+PREF_8B10B_NUM-1);
  localparam int  NUM_WD_2        = (BLOCK_NUM/2 > 1) ? $clog2(BLOCK_NUM/2) : 1;

  typedef struct packed {
    logic                   dv;
    logic [SYM_10B_WD-1:0]  data;
    logic                   com;
    logic                   skp;
    logic [2:0]             tmp;
  }  esdata_8b10b_t;

  typedef struct packed {
    logic                    dv;
    logic [SYM_WD-1:0]       data;
    logic                    hv;
    logic [SYNC_HDR_WD-1:0]  hdr;
    logic                    err;
    os_t                     os;
  }  esdata_128b130b_t;

  typedef struct packed {
    logic                    dv;
    logic [SYM_WD-1:0]       data;
    logic                    hv;
    logic [SYNC_HDR_WD-1:0]  hdr;
    os_t                     os;
    logic                    os_corrected;
  }  esdata_1b1b_t;

  typedef union packed {
    esdata_8b10b_t     data_8b10b;
    esdata_128b130b_t  data_128b130b;
    esdata_1b1b_t  data_1b1b;
  }  esdata_u;

  function automatic integer  get_pref_num (
    logic [PHY_SYM_WD-1:0]  symbol_width,
    logic                   encdec_8b10b
    ,
    logic                   gen6_rate
  );
    integer  ret;
    ret = 0;
    if(encdec_8b10b) begin
      ret = $bits(ret)'((symbol_width > 2) ? symbol_width : 2);
    end
    else if(gen6_rate) begin
      ret = $bits(ret)'((symbol_width > BLOCK_INT_GEN6) ? symbol_width : BLOCK_INT_GEN6);
    end
    else begin
      ret = $bits(ret)'((symbol_width > BLOCK_INT) ? symbol_width : BLOCK_INT);
    end
    return ret;
  endfunction

  // making : "ptr mod DEPTH"
  function automatic logic [ADDR_WD-1:0]  calc_cur_ptr (
    logic [ADDR_WD-1:0]   ptr,
    logic [WIDTH_WD-1:0]  pipe_width,
    logic [ADDR_WD-1:0] roll_over_thres_hold  [PHY_NB-1:0]
  );
  
    logic [PHY_NB-1:0] comp_bitmap , comp_bitmap_1hot;
    logic [LOG2_PHY_NB-1:0] msb_posi , subtract_times ;
    logic                   srch_break ;
    logic  [ADDR_WD-1:0] temp_index [LOG2_PHY_NB-1:0] ;

    // compare with all threshold
    for( int ii = 0 ; ii < PHY_NB ; ii++ ) begin
        comp_bitmap[ii] = ( ptr >= roll_over_thres_hold[ii] ) ? 1'b1 : 1'b0 ;
    end

   // find the msb bit value is 1.
    msb_posi = 0 ;
    srch_break = 0 ;
    for( int ii = 0 ; ii < PHY_NB ; ii++ ) begin
        if( comp_bitmap[PHY_NB-1-ii] && ~srch_break ) begin
            msb_posi = PHY_NB-1-ii ;
            srch_break = 1 ;
        end
    end

    subtract_times = ( msb_posi >> (LOG2_PHY_NB - pipe_width) ) << (LOG2_PHY_NB - pipe_width) ;
 
   // subtract 
    calc_cur_ptr = $bits(calc_cur_ptr)'((ptr - roll_over_thres_hold[subtract_times]) << pipe_width) ;
  endfunction
  
  function automatic logic [ADDR_WD-1:0]  calc_up_ptr_addr (
    logic [ADDR_WD-1:0]  ptr,
    logic [ADDR_WD-1:0]  offset
  );
    logic [ADDR_WD-1:0]  ret;
    if(DEPTH > (ptr + offset)) begin
      ret = $bits(ret)'(ptr + offset);
    end
    else begin
      ret = $bits(ret)'(ptr + offset - DEPTH);
    end
    return ret;
  endfunction

  function automatic logic [ADDR_WD-1:0]  calc_down_ptr_addr (
    logic [ADDR_WD-1:0]  ptr,
    logic [ADDR_WD-1:0]  offset
  );
    logic [ADDR_WD-1:0]  ret;
    if(ptr >= offset) begin
      ret = $bits(ret)'(ptr - offset);
    end
    else begin
      ret = $bits(ret)'(ptr + DEPTH - offset);
    end
    return ret;
  endfunction

// --------------------------------------------------------------------------------
//  Common internal signal (rx_clk)
// --------------------------------------------------------------------------------
  logic [ADDR_WD-1:0] raw_wr_ptr;
  logic  estore_wr_sync_rst;
  logic  wr_sync_rst;
  assign estore_wr_sync_rst = wr_sync_rst || estore_rx_sync_rst;

// --------------------------------------------------------------------------------
//  Common internal signal (clk)
// --------------------------------------------------------------------------------
  logic [$clog2(PREF_NUM+1)-1:0]  pref_symbol_width;
  assign pref_symbol_width = get_pref_num(symbol_width, encdec_8b10b, (pipe_rate inside {`GEN6_RATE}) );

  logic [ADDR_WD-1:0]  wr_ptr_sync, wr_ptr_sync_comb, raw_wr_ptr_sync;
  logic [ADDR_WD:0]  wr_ptr_sync_pls_dp_comb ,  wr_ptr_sync_pls_dp ;
  logic [ADDR_WD-1:0] roll_over_thres_hold_clk    [PHY_NB-1:0] ;


  // Make muliple 0 to PHY_NB (fixed value)
  always_comb begin
    for( int ii = 0 ; ii < PHY_NB ; ii++ ) begin
      roll_over_thres_hold_clk[ii]   = (ADDR_WD)'( ((DEPTH * ii) >> LOG2_PHY_NB) + PTR_OFFSET );
    end
  end
  
  assign wr_ptr_sync_comb        = calc_cur_ptr(raw_wr_ptr_sync, pipe_width, roll_over_thres_hold_clk);
  assign wr_ptr_sync_pls_dp_comb = $bits(wr_ptr_sync_pls_dp_comb)'( wr_ptr_sync_comb + DEPTH ) ;

  always_ff @(posedge clk or negedge rst_n) begin: wr_ptr_sync_PROC
    if(!rst_n) begin
      wr_ptr_sync <= #`TP 1'h0;
      wr_ptr_sync_pls_dp <= #`TP 1'h0;
    end
    else begin
      wr_ptr_sync        <= #`TP wr_ptr_sync_comb;
      wr_ptr_sync_pls_dp <= #`TP wr_ptr_sync_pls_dp_comb;
    end
  end
  
  
  
  logic [ADDR_WD-1:0] rd_ptr;

  logic  estore_rd_sync_rst;
  logic  rd_sync_rst, rd_sync_rst_in_prog, rd_sync_rst_in_prog_d ;
  assign estore_rd_sync_rst = estore_sync_rst || (rd_sync_rst || rd_sync_rst_in_prog || rd_sync_rst_in_prog_d);

  always_ff @(posedge clk or negedge rst_n) begin: rd_sync_rst_in_prog_d_PROC
    if(!rst_n) begin
      rd_sync_rst_in_prog_d <= #`TP 1'h0;
    end
    else begin
      rd_sync_rst_in_prog_d <= #`TP rd_sync_rst_in_prog;
    end
  end
  

  logic [PHY_NB+PREF_NUM-1:0]  rd_en;
  logic                        rd_valid;

  esdata_128b130b_t [PHY_NB-1:0]  skp_sdata_128b130b;

  logic [SYM_WD-1:0]  skp_id_128b130b;

  always_comb begin: skp_id_128b130b_PROC
    case(pipe_rate)
      `GEN5_RATE: skp_id_128b130b = SYM_GEN5_SKP;
      default: skp_id_128b130b = SYM_GEN3_SKP;
    endcase
  end


// --------------------------------------------------------------------------------
//  Write control
// --------------------------------------------------------------------------------
  logic  wr_datavalid;

  always_comb begin: wr_datavalid_PROC
    wr_datavalid = 1'h0;
    if(pipe_rxvalid) begin
      if(encdec_8b10b_sync2rx) begin
        wr_datavalid = (symbol_locked) ? 1'h1 : 1'h0;
      end
      else begin
        wr_datavalid = (block_aligned) ? 1'h1 : 1'h0;
      end
    end
    if(drift_buffer_en) begin
      wr_datavalid = 1'h0;
    end
  end

  logic  wr_valid, int_wr_valid;

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: int_wr_valid_PROC
    if(!rx_rst_n) begin
      int_wr_valid <= #`TP 1'h0;
    end
    else if(estore_wr_sync_rst) begin
      int_wr_valid <= #`TP 1'h0;
    end
    else if(wr_datavalid) begin
      int_wr_valid <= #`TP 1'h1;
    end
  end

  always_comb begin: wr_valid_PROC
    wr_valid = 1'h0;
    if(wr_datavalid) begin
      wr_valid = 1'h1;
      if(!encdec_8b10b_sync2rx) begin
        if(!decoded_rxdatavalid) begin
          wr_valid = 1'h0;
        end
      end
    end
    else if(int_wr_valid) begin
      wr_valid = 1'h1;
    end
  end

  logic [PHY_NB-1:0]  wr_en;

  always_comb begin: wr_en_PROC
    wr_en = '0;
    if(wr_valid) begin
      for(int i = 0; i < PHY_NB; i++) begin
        if(symbol_width_sync2rx > i) begin
          wr_en[i] = 1'h1;
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  Write data
// --------------------------------------------------------------------------------
  esdata_u [PHY_NB-1:0]  wr_udata;

// spyglass disable_block AlwaysCombExhaustive-ML
// SMD: Not all conditions are covered for the combinational logic.
// SJ: A default value is defined to avoid a latch.
  always_comb begin: wr_udata_PROC
    wr_udata = '0;
    if(encdec_8b10b_sync2rx) begin
      for(int i = 0; i < PHY_8B10B_NB; i++) begin
        wr_udata[i].data_8b10b.dv = wr_datavalid;
        wr_udata[i].data_8b10b.data = locked_rxdata[i];
        if(wr_datavalid) begin
          wr_udata[i].data_8b10b.com = (locked_rxdata[i] inside {SYM_10B_COM, ~SYM_10B_COM});
          wr_udata[i].data_8b10b.skp = (locked_rxdata[i] inside {SYM_10B_SKP, ~SYM_10B_SKP});
        end
      end
    end
    else if(pipe_rate_sync2rx inside {`GEN6_RATE}) begin
      for(int i = 0; i < PHY_NB; i++) begin
        wr_udata[i].data_1b1b.dv = wr_datavalid;
        wr_udata[i].data_1b1b.data = decoded_rxdata[i];
        wr_udata[i].data_1b1b.os = decoded_os_found[i/BLOCK_INT_GEN6];
        wr_udata[i].data_1b1b.os_corrected = osfind_os_corrected;
        if((i % BLOCK_INT_GEN6) == 0) begin
          if(decoded_rxstartblock[i/BLOCK_INT_GEN6]) begin
            wr_udata[i].data_1b1b.hv = 1'h1;
            wr_udata[i].data_1b1b.hdr = decoded_rxsyncheader[i/BLOCK_INT_GEN6];
          end
        end
      end
    end
    else begin
      for(int i = 0; i < PHY_128B130B_NB; i++) begin
        wr_udata[i].data_128b130b.dv = wr_datavalid;
        wr_udata[i].data_128b130b.data = decoded_rxdata[i];
        wr_udata[i].data_128b130b.os = decoded_os_found[i/BLOCK_INT];
        wr_udata[i].data_128b130b.err = err_undef_skp;
        if((i % BLOCK_INT) == 0) begin
          if(decoded_rxstartblock[i/BLOCK_INT]) begin
            wr_udata[i].data_128b130b.hv = 1'h1;
            wr_udata[i].data_128b130b.hdr = decoded_rxsyncheader[i/BLOCK_INT];
          end
        end
      end
    end
  end
// spyglass enable_block AlwaysCombExhaustive-ML

// --------------------------------------------------------------------------------
//  Buffer with read data gating
// --------------------------------------------------------------------------------
  esdata_u [PHY_NB+PREF_NUM-1:0]  gated_rd_udata;

  serdes_pipe_rx_subestore
   #(
    .DEPTH(DEPTH),
    .ADDR_WD(ADDR_WD),
    .DATA_WD($bits(esdata_u)),
    .WR_WD(WR_WD),
    .RD_WD(RD_WD)
  ) u_serdes_pipe_rx_subestore (
    // ---------- input (clk) --------------
    .clk(clk),
    .rst_n(rst_n),
    .rd_en(rd_en),
    .rd_ptr(rd_ptr),
    // ---------- input (rx_clk) -----------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .buf_sync_rst(estore_wr_sync_rst),
    .symbol_width_sync2rx(symbol_width_sync2rx),
    .wr_en(wr_en),
    .wrdata(wr_udata),
    // ---------- output (clk) -------------
    .rddata(gated_rd_udata)
  );

// --------------------------------------------------------------------------------
//  BCM: reset synchronizer
// --------------------------------------------------------------------------------
  DWC_pcie_ctl_bcm37
   #(
    .F_SYNC_TYPE(SYNC_TYPE),
    .R_SYNC_TYPE(SYNC_TYPE),
    .REG_IN_PROG(0),
    .VERIF_EN(1)
  ) u_DWC_pcie_ctl_bcm37 (
    // ---------- input (clk) --------------
    .clk_d(clk),
    .rst_d_n(rst_n),
    .init_d_n(1'h1),
    .clr_d(rd_sync_rst),
    // ---------- input (rx_clk) -----------
    .clk_s(rx_clk),
    .rst_s_n(rx_rst_n),
    .init_s_n(1'h1),
    .clr_s(1'h0),
    // ---------- output (clk) -------------
    .clr_in_prog_d(rd_sync_rst_in_prog),
    .clr_sync_d(),
    .clr_cmplt_d(),
    // ---------- output (rx_clk) ----------
    .clr_sync_s(),
    .clr_in_prog_s(wr_sync_rst),
    .clr_cmplt_s()
  );

// --------------------------------------------------------------------------------
//  BCM: gray coded synchronizer
// --------------------------------------------------------------------------------
  DWC_pcie_ctl_bcm24
   #(
    .WIDTH(ADDR_WD),
    .OFFSET(PTR_OFFSET),
    .REG_COUNT_D(0),
    .F_SYNC_TYPE(SYNC_TYPE),
    .VERIF_EN(1),
    .PIPE_DELAY(0),
    .REG_COUNT_S(0),
    .REG_OFFSET_COUNT_S(1)
  ) u_DWC_pcie_ctl_bcm24 (
    // ---------- input (clk) --------------
    .clk_d(clk),
    .rst_d_n(rst_n),
    .init_d_n(1'h1),
    // ---------- input (rx_clk) -----------
    .clk_s(rx_clk),
    .rst_s_n(rx_rst_n),
    .init_s_n(!estore_wr_sync_rst),
    .en_s(wr_valid),
    // ---------- output (clk) -------------
    .count_d(raw_wr_ptr_sync),
    // ---------- output (rx_clk) ----------
    .count_s(),
    .offset_count_s(raw_wr_ptr)
  );

// --------------------------------------------------------------------------------
//  Read pointer
// --------------------------------------------------------------------------------
  logic [ADDR_WD-1:0]  next_rd_ptr_8b10b;
  logic [ADDR_WD-1:0]  next_rd_ptr_128b130b;
  logic [ADDR_WD-1:0]  next_rd_ptr_1b1b;

  always_ff @(posedge clk or negedge rst_n) begin: rd_ptr_8b10b_PROC
    if(!rst_n) begin
        rd_ptr <= #`TP '0 ;
    end
    else if(estore_rd_sync_rst) begin
        rd_ptr <= #`TP '0 ;
    end
    else if(encdec_8b10b) begin
      if(rd_valid) begin
          rd_ptr <= #`TP next_rd_ptr_8b10b;
      end
    end
    else if(pipe_rate inside {`GEN6_RATE}) begin
      if(rd_valid) begin
          rd_ptr <= #`TP next_rd_ptr_1b1b;
      end
    end
    else begin
      if(rd_valid) begin
          rd_ptr <= #`TP next_rd_ptr_128b130b;
      end
    end
  end

  logic [ADDR_WD-1:0]  cur_buf_depth;
  assign cur_buf_depth = (wr_ptr_sync >= rd_ptr ) ? $bits(cur_buf_depth)'( wr_ptr_sync        - rd_ptr )
                                                  : $bits(cur_buf_depth)'( wr_ptr_sync_pls_dp - rd_ptr ) ;

// --------------------------------------------------------------------------------
//  Nominal empty mode control
// --------------------------------------------------------------------------------
  logic  buf_empty_mode, buf_empty_mode_d;
  logic  chg_buf_mode_halffull;
  assign buf_empty_mode = pipe_elasticbuffermode && !pipe_loopback_slave;
  assign chg_buf_mode_halffull = !buf_empty_mode && buf_empty_mode_d;

  always_ff @(posedge clk or negedge rst_n) begin: buf_empty_mode_d_PROC
    if(!rst_n) begin
      buf_empty_mode_d <= #`TP 1'h0;
    end
    else if(estore_rd_sync_rst) begin
      buf_empty_mode_d <= #`TP 1'h0;
    end
    else begin
      buf_empty_mode_d <= #`TP buf_empty_mode;
    end
  end

// --------------------------------------------------------------------------------
//  Buffer underflow / overflow detection
// --------------------------------------------------------------------------------
  logic [ADDR_WD-1:0]  buf_underflow_depth, buf_overflow_depth;
  assign buf_underflow_depth = $bits(buf_underflow_depth)'(symbol_width);
  assign buf_overflow_depth = $bits(buf_overflow_depth)'(DEPTH - (MAX_SYNC_DELAY << pipe_width));

  logic  buf_underflow_detected, buf_overflow_detected;
  assign buf_underflow_detected = (cur_buf_depth < buf_underflow_depth);
  assign buf_overflow_detected = (cur_buf_depth > buf_overflow_depth);

  logic [ADDR_WD-1:0]  buf_almost_overflow_depth, buf_almost_overflow_depth_comb ;
  assign buf_almost_overflow_depth_comb = $bits(buf_almost_overflow_depth)'(buf_overflow_depth - symbol_width);

  localparam int WIDTH_RST_VAL = (`CX_PHY_NB_GEN1 == 4) ? 2:
                                 (`CX_PHY_NB_GEN1 == 2) ? 1:
                                                          0;

  always_ff @(posedge clk or negedge rst_n) begin: buf_almost_overflow_depth_PROC
    if(!rst_n) begin
      buf_almost_overflow_depth     <= #`TP $bits(buf_almost_overflow_depth)'( DEPTH - (MAX_SYNC_DELAY << WIDTH_RST_VAL) ) ;
    end
    else begin
      buf_almost_overflow_depth     <= #`TP buf_almost_overflow_depth_comb;
    end
  end

  logic  buf_almost_underflow_detected, buf_almost_overflow_detected;
  assign buf_almost_underflow_detected = rd_valid && (!buf_empty_mode && buf_underflow_detected);
  assign buf_almost_overflow_detected = rd_valid && (cur_buf_depth > buf_almost_overflow_depth);

// --------------------------------------------------------------------------------
//  Read start control
// --------------------------------------------------------------------------------
  logic [ADDR_WD-1:0]  buf_halffull_depth, buf_empty_depth;
  logic [ADDR_WD-1:0]  rd_start_depth ;
  logic [ADDR_WD-1:0]  buf_halffull_depth_r, buf_empty_depth_r;
  assign buf_empty_depth     = $bits(buf_empty_depth)'(symbol_width + pref_symbol_width);
  assign rd_start_depth      = (buf_empty_mode) ? buf_empty_depth_r : buf_halffull_depth_r;

  always_ff @(posedge clk or negedge rst_n) begin: rd_start_depth_PROC
    if(!rst_n) begin
      buf_halffull_depth_r     <= #`TP `CX_EBUF_HALFFULL_DEPTH_GEN1_SRNS ;
      buf_empty_depth_r        <= #`TP `CX_PHY_NB_GEN1 << 1 ;
    end
    else begin
      buf_halffull_depth_r     <= #`TP buf_halffull_depth;
      buf_empty_depth_r        <= #`TP buf_empty_depth ;
    end
  end

  always_comb begin: buf_halffull_depth_PROC
    buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN1_SRNS;
    case(pipe_rate)
      RATE_WD'(`GEN1_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN1_SRNS;
      RATE_WD'(`GEN2_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN2_SRNS;
      RATE_WD'(`GEN3_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN3_SRNS;
      RATE_WD'(`GEN4_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN4_SRNS;
      RATE_WD'(`GEN5_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN5_SRNS;
      RATE_WD'(`GEN6_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN6_SRNS;
      default: buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN1_SRNS;
    endcase
    if(pipe_srisen) begin
      case(pipe_rate)
        RATE_WD'(`GEN1_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN1_SRIS;
        RATE_WD'(`GEN2_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN2_SRIS;
        RATE_WD'(`GEN3_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN3_SRIS;
        RATE_WD'(`GEN4_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN4_SRIS;
        RATE_WD'(`GEN5_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN5_SRIS;
        RATE_WD'(`GEN6_RATE): buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN6_SRIS;
        default: buf_halffull_depth = `CX_EBUF_HALFFULL_DEPTH_GEN1_SRIS;
      endcase
    end
  end

  logic  do_rd_start;
  logic  rd_in_prog, int_rd_in_prog;
  assign do_rd_start = (cur_buf_depth >= rd_start_depth) && !buf_overflow_detected;
  assign rd_in_prog = (chg_buf_mode_halffull) ? 1'h0 : int_rd_in_prog;

  always_ff @(posedge clk or negedge rst_n) begin: int_rd_in_prog_PROC
    if(!rst_n) begin
      int_rd_in_prog <= #`TP 1'h0;
    end
    else if(estore_rd_sync_rst) begin
      int_rd_in_prog <= #`TP 1'h0;
    end
    else if(do_rd_start) begin
      int_rd_in_prog <= #`TP 1'h1;
    end
    else if(chg_buf_mode_halffull) begin
      int_rd_in_prog <= #`TP 1'h0;
    end
  end

// --------------------------------------------------------------------------------
//  SKP add / remove control
// --------------------------------------------------------------------------------
  logic [ADDR_WD-1:0]  skp_add_depth, skp_rem_depth;
  logic [ADDR_WD-1:0]  skp_add_depth_comb, skp_rem_depth_comb;
  assign skp_add_depth_comb = $bits(skp_add_depth)'(buf_halffull_depth - symbol_width - pref_symbol_width);
  assign skp_rem_depth_comb = $bits(skp_rem_depth)'(buf_halffull_depth + symbol_width + pref_symbol_width);

  always_ff @(posedge clk or negedge rst_n) begin: skp_depth_PROC
    if(!rst_n) begin
      skp_add_depth <= #`TP `CX_EBUF_HALFFULL_DEPTH_GEN1_SRNS - (`CX_PHY_NB_GEN1 << 1) ;
      skp_rem_depth <= #`TP `CX_EBUF_HALFFULL_DEPTH_GEN1_SRNS + (`CX_PHY_NB_GEN1 << 1) ;
    end
    else begin
      skp_add_depth <= #`TP skp_add_depth_comb;
      skp_rem_depth <= #`TP skp_rem_depth_comb;
    end
  end


  logic  do_skp_add, do_skp_rem;

  always_comb begin: do_skp_add_PROC
    do_skp_add = 1'h0;
    do_skp_rem = 1'h0;
    if(buf_empty_mode) begin
      do_skp_add = 1'h0;
      do_skp_rem = 1'h1;
    end
    else begin
      do_skp_add = (cur_buf_depth <= skp_add_depth);
      do_skp_rem = (cur_buf_depth >= skp_rem_depth);
    end
    if(sync_hdr_bypass_en) begin
      do_skp_add = 1'h0;
      do_skp_rem = 1'h0;
    end
  end

  logic  done_skp_add_8b10b, done_skp_rem_8b10b;
  logic  post_skp_add_8b10b;
  logic  done_skp_add_128b130b, done_skp_rem_128b130b;
  logic  post_skp_add_128b130b;
  logic  done_skp_add_1b1b, done_skp_rem_1b1b;
  logic  post_skp_add_1b1b;

// --------------------------------------------------------------------------------
//  Read control
// --------------------------------------------------------------------------------
  logic [PHY_NB-1:0]    int_rd_en;
  logic [PREF_NUM-1:0]  pref_rd_en;
  assign rd_en = $bits(rd_en)'(int_rd_en | (pref_rd_en << symbol_width));

  always_comb begin: int_rd_en_PROC
    int_rd_en = '0;
    if(!buf_overflow_detected && !buf_underflow_detected) begin
      if(!estore_sync_rst && !rd_sync_rst_in_prog) begin
        for(int i = 0; i < PHY_NB; i++) begin
          if(symbol_width > i) begin
            int_rd_en[i] = 1'h1;
          end
        end
      end
    end
  end

  always_comb begin: pref_rd_en_PROC
    logic  l_pref_rd_en_s0;
    logic  l_pref_rd_en;
    l_pref_rd_en_s0 = (cur_buf_depth >= $bits(cur_buf_depth)'(symbol_width + 1));
    l_pref_rd_en = (cur_buf_depth >= buf_empty_depth_r);
    pref_rd_en = '0;
    if(!buf_overflow_detected && !buf_underflow_detected) begin
      if(!estore_sync_rst && !rd_sync_rst_in_prog) begin
        if(l_pref_rd_en_s0) begin
          pref_rd_en[0] = 1'h1;
        end
        if(l_pref_rd_en) begin
          for(int i = 0; i < PREF_NUM; i++) begin
            if(pref_symbol_width > i) begin
              pref_rd_en[i] = 1'h1;
            end
          end
        end
      end
    end
  end

  logic  buf_empty_rd_valid, buf_halffull_rd_valid;

  always_comb begin: rd_valid_PROC
    rd_valid = (buf_empty_mode) ? buf_empty_rd_valid : buf_halffull_rd_valid;
  end

  always_comb begin: buf_empty_rd_valid_PROC
    buf_empty_rd_valid = 1'h0;
    buf_halffull_rd_valid = 1'h0;
    if(!estore_sync_rst && !rd_sync_rst_in_prog) begin
      buf_empty_rd_valid = do_rd_start;
      buf_halffull_rd_valid = do_rd_start || rd_in_prog;
    end
  end

  logic  rd_datavalid;
  logic  rd_deadcycle;

  always_comb begin: rd_datavalid_PROC
    rd_datavalid = 1'h0;
    if(rd_valid) begin
      rd_datavalid = 1'h1;
      if(!encdec_8b10b && !buf_empty_mode) begin
        if(rd_deadcycle) begin
          rd_datavalid = 1'h0;
        end
      end
      if(sync_hdr_bypass_en || (pipe_rate inside {`GEN6_RATE})) begin
        rd_datavalid = 1'h1;
      end
    end
  end

// --------------------------------------------------------------------------------
//  Dead cycle control
// --------------------------------------------------------------------------------
  logic  startblock_found;
  logic  pre_startblock_found, pre_startblock_found_d;
  assign startblock_found = pre_startblock_found || pre_startblock_found_d;

  always_comb begin: pre_startblock_found_PROC
    pre_startblock_found = 1'h0;
    if(rd_datavalid) begin
      for(int i = 0; i < PHY_NB; i++) begin
        if((i % BLOCK_INT) == 0) begin
          if(symbol_width > i) begin
            pre_startblock_found |= skp_sdata_128b130b[i].hv;
          end
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin: pre_startblock_found_d_PROC
    if(!rst_n) begin
      pre_startblock_found_d <= #`TP 1'h0;
    end
    else if(estore_rd_sync_rst) begin
      pre_startblock_found_d <= #`TP 1'h0;
    end
    else if(!encdec_8b10b) begin
      if(pre_startblock_found) begin
        pre_startblock_found_d <= #`TP 1'h1;
      end
    end
  end

  logic [$clog2(PHY_RXSB_WD+1)-1:0]  rd_startblock_num;

  always_comb begin: rd_startblock_num_PROC
    rd_startblock_num = '0;
    for(int i = 0; i < PHY_NB; i++) begin
      if((i % BLOCK_INT) == 0) begin
        if(symbol_width > i) begin
          if(skp_sdata_128b130b[i].hv) begin
            rd_startblock_num = $bits(rd_startblock_num)'(rd_startblock_num + 1);
          end
        end
      end
    end
  end

  logic [SB_CNT_WD-1:0]  startblock_cnt, max_startblock_num;
  logic                  startblock_cnt_expired;
  assign max_startblock_num = $bits(max_startblock_num)'(raw_width >> $clog2(SYNC_HDR_WD));
  assign rd_deadcycle = startblock_cnt_expired;

  always_comb begin: startblock_cnt_expired_PROC
    if(startblock_cnt == max_startblock_num) begin
       startblock_cnt_expired = (rd_startblock_num > 0);
    end
    else begin
      startblock_cnt_expired = (startblock_cnt > max_startblock_num);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin: startblock_cnt_PROC
    if(!rst_n) begin
      startblock_cnt <= #`TP '0;
    end
    else if(estore_rd_sync_rst || buf_empty_mode) begin
      startblock_cnt <= #`TP '0;
    end
    else if(!encdec_8b10b) begin
      if(rd_valid) begin
        if(startblock_cnt_expired) begin
          startblock_cnt <= #`TP $bits(startblock_cnt)'(startblock_cnt - max_startblock_num);
        end
        else begin
          startblock_cnt <= #`TP $bits(startblock_cnt)'(startblock_cnt + rd_startblock_num);
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  Read clear
// --------------------------------------------------------------------------------
  logic  invalid_rddata_found;
  logic  err_rddata_found;

  always_comb begin: rd_sync_rst_PROC
    rd_sync_rst = 1'h0;
    if(rd_valid) begin
      rd_sync_rst = invalid_rddata_found && !buf_almost_underflow_detected;
      if(!encdec_8b10b && !pipe_loopback_slave) begin
        if(err_rddata_found) begin
          rd_sync_rst = 1'h1;
        end
        if(buf_almost_underflow_detected || buf_almost_overflow_detected) begin
          rd_sync_rst = 1'h1;
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  Read buffer with gating
// --------------------------------------------------------------------------------
  esdata_8b10b_t [(PHY_8B10B_NB+PREF_8B10B_NUM)-1:0]  rd_sdata_8b10b;

  always_comb begin: rd_sdata_8b10b_PROC
    for(int i = 0; i < (PHY_8B10B_NB + PREF_8B10B_NUM); i++) begin
      rd_sdata_8b10b[i] = gated_rd_udata[i].data_8b10b;
    end
    if(post_skp_add_8b10b) begin
      rd_sdata_8b10b[0] = '{dv: 1'h1, data: gated_rd_udata[1].data_8b10b.data, skp: 1'h1, default: '0};
    end
  end

  esdata_128b130b_t [BLOCK_NUM-1:0][BLOCK_INT-1:0]  rd_sdata_128b130b;

  always_comb begin: rd_sdata_128b130b_PROC
    esdata_128b130b_t [(PHY_128B130B_NB+PREF_128B130B_NUM)-1:0]  l_rd_sdata;
    for(int i = 0; i < (PHY_128B130B_NB + PREF_128B130B_NUM); i++) begin
      l_rd_sdata[i] = gated_rd_udata[i].data_128b130b;
    end
    if(post_skp_add_128b130b) begin
      for(int i = 0; i < BLOCK_INT; i++) begin
        l_rd_sdata[i] = '{dv: 1'h1, data: skp_id_128b130b, os: SKP, default: '0};
      end
    end
    rd_sdata_128b130b = $bits(rd_sdata_128b130b)'(l_rd_sdata);
  end

  esdata_1b1b_t [BLOCK_NUM_GEN6-1:0][BLOCK_INT_GEN6-1:0]  rd_sdata_1b1b;

  always_comb begin: rd_sdata_1b1b_PROC
    esdata_1b1b_t [(PHY_NB+PREF_NUM)-1:0]  l_rd_sdata;
    for(int i = 0; i < (PHY_NB + PREF_NUM); i++) begin
      l_rd_sdata[i] = gated_rd_udata[i].data_1b1b;
    end
    // TBD
    if(post_skp_add_1b1b) begin
      for(int i = 0; i < BLOCK_INT_GEN6; i++) begin
        if(i % 2 == 0) begin
          l_rd_sdata[i] = '{dv: 1'h1, data: 'hF0, os: SKP, default: '0};
        end 
        else begin
          l_rd_sdata[i] = '{dv: 1'h1, data: 'h0F, os: SKP, default: '0};
        end
      end
    end
    rd_sdata_1b1b = $bits(rd_sdata_1b1b)'(l_rd_sdata);
  end

// --------------------------------------------------------------------------------
//  SKP OS finding
// --------------------------------------------------------------------------------
  logic [PHY_8B10B_NB-1:0]                   skpos_found_add_8b10b;
  logic [(PHY_8B10B_NB+PREF_8B10B_NUM)-2:0]  skpos_found_rem_8b10b;

  always_comb begin: skpos_found_add_8b10b_PROC
    skpos_found_add_8b10b = '0;
    for(int i = 0; i < PHY_8B10B_NB; i++) begin
      skpos_found_add_8b10b[i] = rd_sdata_8b10b[i].com && rd_sdata_8b10b[i+1].skp;
    end
  end

  always_comb begin: skpos_found_rem_8b10b_PROC
    skpos_found_rem_8b10b = '0;
    if(pipe_loopback_slave) begin
      for(int i = 0; i < ((PHY_8B10B_NB + PREF_8B10B_NUM) - 2); i++) begin
        skpos_found_rem_8b10b[i] = (rd_sdata_8b10b[i].com && rd_sdata_8b10b[i+1].skp) && rd_sdata_8b10b[i+2].skp;
      end
    end
    else begin
      for(int i = 0; i < ((PHY_8B10B_NB + PREF_8B10B_NUM) - 1); i++) begin
        skpos_found_rem_8b10b[i] = rd_sdata_8b10b[i].com && rd_sdata_8b10b[i+1].skp;
      end
    end
  end

  logic [BLOCK_NUM-2:0]  skpos_hdr_found_128b130b;
  logic [BLOCK_NUM-2:0]  skpos_found_add_128b130b, skpos_found_rem_128b130b;
  assign skpos_found_add_128b130b = skpos_hdr_found_128b130b;

  always_comb begin: skpos_hdr_found_128b130b_PROC
    skpos_hdr_found_128b130b = '0;
    for(int i = 0; i < (BLOCK_NUM - 1); i++) begin
      // This condition will be replaced with OS flag info
      if(rd_sdata_128b130b[i][0].dv == 1'h1 && rd_sdata_128b130b[i][0].data == skp_id_128b130b && rd_sdata_128b130b[i][0].hv == 1'h1 && rd_sdata_128b130b[i][0].hdr == SYNC_HDR_OS && rd_sdata_128b130b[i][0].err == 1'h0) begin
        skpos_hdr_found_128b130b[i] = 1'h1;
      end
    end
  end

  always_comb begin: skpos_found_rem_128b130b_PROC
    skpos_found_rem_128b130b = skpos_hdr_found_128b130b;
    for(int i = 0; i < (BLOCK_NUM - 1); i++) begin
      for(int j = 1; j < BLOCK_INT; j++) begin
        if(!rd_sdata_128b130b[i][j].dv || rd_sdata_128b130b[i][j].err) begin
          skpos_found_rem_128b130b[i] = 1'h0;
        end
      end
      if(pipe_loopback_slave) begin
        // This condition will be replaced with OS flag info
        if(!(rd_sdata_128b130b[i+1][0].dv == 1'h1 && rd_sdata_128b130b[i+1][0].data == skp_id_128b130b && rd_sdata_128b130b[i+1][0].hv == 1'h0 && rd_sdata_128b130b[i+1][0].hdr == '0 && rd_sdata_128b130b[i+1][0].err == 1'h0)) begin
          skpos_found_rem_128b130b[i] = 1'h0;
        end
      end
    end
  end

// TBD
  logic [BLOCK_NUM_GEN6-2:0]  skpos_hdr_found_1b1b;
  logic [BLOCK_NUM_GEN6-2:0]  skpos_found_add_1b1b, skpos_found_rem_1b1b;
  assign skpos_found_add_1b1b = skpos_hdr_found_1b1b;

  always_comb begin: skpos_hdr_found_1b1b_PROC
    // esdata_1b1b_t  l_skpos_hdr;
    // l_skpos_hdr = '{dv: 1'h1, data: 'hF0, hv: 1'h1, hdr: SYNC_HDR_OS, err: 1'h0};
//    esdata_1b1b_t  l_os_hdr;
//    l_os_hdr = '{dv: 1'h1, hv: 1'h1, hdr: SYNC_HDR_OS};
    skpos_hdr_found_1b1b = '0;
    for(int i = 0; i < (BLOCK_NUM_GEN6 - 1); i++) begin
      if(rd_sdata_1b1b[i][0].dv == 1'h1 && rd_sdata_1b1b[i][0].hv == 1'h1 && rd_sdata_1b1b[i][0].hdr == SYNC_HDR_OS) begin
        if(rd_sdata_1b1b[i][0].os == SKP || rd_sdata_1b1b[i+1][0].os == SKP || rd_sdata_1b1b[i+1][0].os == SKP_END ) begin
          skpos_hdr_found_1b1b[i] = 1'h1;
        end
      end
    end
  end

  always_comb begin: skpos_found_rem_1b1b_PROC
    esdata_1b1b_t  l_skpos_symbol;
    l_skpos_symbol = '{dv: 1'h1, data: 'hF0, hv: 1'h0, hdr: '0 , os_corrected: '0 , os: SKP };
    skpos_found_rem_1b1b = skpos_hdr_found_1b1b;
    for(int i = 0; i < (BLOCK_NUM_GEN6 - 1); i++) begin
      for(int j = 1; j < BLOCK_INT_GEN6; j++) begin
        if(!rd_sdata_1b1b[i][j].dv) begin
          skpos_found_rem_1b1b[i] = 1'h0;
        end
      end
      if(pipe_loopback_slave) begin
        if(rd_sdata_1b1b[i+1][0] != l_skpos_symbol) begin
          skpos_found_rem_1b1b[i] = 1'h0;
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  SKP adding for 8b/10b encoding
// --------------------------------------------------------------------------------
  typedef struct packed {
    logic                               en;
    esdata_8b10b_t [PHY_8B10B_NB-1:0]   data;
    logic [$clog2(PHY_8B10B_NB+1)-1:0]  num;
  }  skp_adrm_sdata_8b10b_t ;
  
  skp_adrm_sdata_8b10b_t  skp_add_sdata_8b10b;
  skp_adrm_sdata_8b10b_t  skp_rem_sdata_8b10b;

  logic  skp_add_next_8b10b;
  localparam int LOG2_PHY_8b10b_NB = (PHY_8B10B_NB == 1) ? 1 : $clog2(PHY_8B10B_NB);

  // ------------------------------------------------
  // Support up to 4s PIPE(1s,2s or 4s) for Gen1/2. 
  // Not support 8s or above.
  // ------------------------------------------------
// spyglass disable_block AlwaysCombExhaustive-ML
// SMD: Not all conditions are covered for the combinational logic.
// SJ: A default value is defined to avoid a latch.
  always_comb begin: skp_add_sdata_8b10b_PROC
                                                     skp_add_sdata_8b10b    = '0 ;
     // SKP is found
                                                     skp_add_sdata_8b10b.en = '0 ;
     if( symbol_width == $bits(symbol_width)'( 1 ) ) skp_add_sdata_8b10b.en = skpos_found_add_8b10b[0] ;
     if( symbol_width == $bits(symbol_width)'( 2 ) ) skp_add_sdata_8b10b.en = |skpos_found_add_8b10b[1:0] ;
    
     // How many SKP is added in this cycle.
     // 0 or 1 if 1s/2s PIPE
                                                 skp_add_sdata_8b10b.num = '0 ;
      if( skp_add_sdata_8b10b.en )               skp_add_sdata_8b10b.num = $bits(skp_add_sdata_8b10b.num)'( 1 );

     // Data Shift.
                                                 skp_add_sdata_8b10b.data[0] = rd_sdata_8b10b[0] ;                                                    // No shift Byte0
                                                 skp_add_sdata_8b10b.data[1] = (symbol_width > $bits(symbol_width)'( 1 ) ) ? rd_sdata_8b10b[1] : '0 ; // No shift Byte1

     // SKP OS start from MSB. MSB is COM after Data shift.
                                               skp_add_next_8b10b = '0 ;
     if( symbol_width == $bits(symbol_width)'( 1 ) ) begin      // 1S case
       if( skpos_found_add_8b10b[0] )          skp_add_next_8b10b = 1'b1 ;            // SKP is detected on MSB, SKP symbol is added on next cycle.
     end
     if( symbol_width == $bits(symbol_width)'( 2 ) ) begin      // 2S case
       if( skpos_found_add_8b10b[1] )          skp_add_next_8b10b = 1'b1 ;            // SKP is detected on MSB, SKP symbol is added on next cycle.
     end
  end
// spyglass enable_block AlwaysCombExhaustive-ML

  always_ff @(posedge clk or negedge rst_n) begin: post_skp_add_8b10b_PROC
    if(!rst_n) begin
      post_skp_add_8b10b <= #`TP 1'h0;
    end
    else if(estore_rd_sync_rst) begin
      post_skp_add_8b10b <= #`TP 1'h0;
    end
    else if(encdec_8b10b) begin
      if(rd_datavalid) begin
        // ccx_cond: ; 0; 01; "Possibly redundant condition due to PHY_NB value."
        post_skp_add_8b10b <= #`TP (skp_add_next_8b10b && done_skp_add_8b10b);
      end
    end
  end

// --------------------------------------------------------------------------------
//  SKP removing for 8b/10b encoding
// --------------------------------------------------------------------------------
  // ------------------------------------------------
  // Support up to 4s PIPE(1s,2s or 4s) for Gen1/2. 
  // Not support 8s or above.
  // ------------------------------------------------
// spyglass disable_block AlwaysCombExhaustive-ML
// SMD: Not all conditions are covered for the combinational logic.
// SJ: A default value is defined to avoid a latch.
  always_comb begin: skp_rem_sdata_8b10b_PROC
                                                        skp_rem_sdata_8b10b    = '0 ;
     // SKP is found
                                                        skp_rem_sdata_8b10b.en = '0 ;
     if( symbol_width == $bits(symbol_width)'( 1 ) )    skp_rem_sdata_8b10b.en = skpos_found_rem_8b10b[0] ;
     if( symbol_width == $bits(symbol_width)'( 2 ) )    skp_rem_sdata_8b10b.en = |skpos_found_rem_8b10b[1:0] ;
    
     // How many SKP is remed in this cycle.
     // 0 or 1 if 1s/2s PIPE
                                                        skp_rem_sdata_8b10b.num = '0 ;
      if( skp_rem_sdata_8b10b.en                      ) skp_rem_sdata_8b10b.num = $bits(skp_rem_sdata_8b10b.num)'( 1 );   // One SKP OS case
     if( symbol_width == $bits(symbol_width)'( 2 ) ) begin      // 2S case
      if(  skpos_found_rem_8b10b[2:0] == 3'b101       ) skp_rem_sdata_8b10b.num = $bits(skp_rem_sdata_8b10b.num)'( 2 );   // COM-SKP-COM case. will be COM-COM. For 2s
     end

     // Data Shift.
                                                                    skp_rem_sdata_8b10b.data[0] =  rd_sdata_8b10b[0] ;        // No shift Byte0
                                                                    skp_rem_sdata_8b10b.data[1] =  (symbol_width > $bits(symbol_width)'( 1 ) ) ? rd_sdata_8b10b[1] : '0 ;
     if( symbol_width >= $bits(symbol_width)'( 2 ) ) begin    // 2S/4S case
      if( skpos_found_rem_8b10b[0] == 1'b1  )                       skp_rem_sdata_8b10b.data[1] = rd_sdata_8b10b[2] ; // COM-SKP case. will be COM-any
     end
  end
// spyglass enable_block AlwaysCombExhaustive-ML




// --------------------------------------------------------------------------------
//  SKP adding for 128b/130b encoding
// --------------------------------------------------------------------------------
  struct packed {
    logic                                                 en;
    esdata_128b130b_t [(BLOCK_NUM/2)-1:0][BLOCK_INT-1:0]  data;
    logic [$clog2((BLOCK_NUM/2)+1)-1:0]                   num;
  }  skp_add_sdata_128b130b, skp_rem_sdata_128b130b;

  logic  skp_add_next_128b130b;

// spyglass disable_block W468
// SMD: Variable/signal which cannot index the full range of this vector.
// SJ: It is expected that 'l_ptr' only points to the first half part of 'rd_sdata_128b130b' and 'skpos_found_add_128b130b'.
  always_comb begin: skp_add_sdata_128b130b_PROC
    logic [NUM_WD_2-1:0]  l_ptr;
    skp_add_sdata_128b130b = '0;
    skp_add_next_128b130b = 1'h0;
    for(int i = 0; i < (BLOCK_NUM / 2); i++) begin
      l_ptr = $bits(l_ptr)'(i - skp_add_sdata_128b130b.num);
      if(symbol_width > (BLOCK_INT * i)) begin
        skp_add_sdata_128b130b.data[i] = rd_sdata_128b130b[l_ptr];
        if(skp_add_next_128b130b) begin
          // ccx_line_begin: ; "Possibly redundant lines due to PHY_NB value."
          skp_add_sdata_128b130b.data[i][0].hv = 1'h0;
          skp_add_sdata_128b130b.data[i][0].hdr = '0;
          skp_add_next_128b130b = 1'h0;
          // ccx_line_end
        end
        else if(skpos_found_add_128b130b[l_ptr]) begin
          skp_add_sdata_128b130b.en = 1'h1;
          skp_add_sdata_128b130b.num = $bits(skp_add_sdata_128b130b.num)'(skp_add_sdata_128b130b.num + 1);
          skp_add_next_128b130b = 1'h1;
        end
      end
    end
  end
// spyglass enable_block W468

  logic [$clog2(BLOCK_INT+1)-1:0]  post_skp_add_128b130b_cnt;
  assign post_skp_add_128b130b = (post_skp_add_128b130b_cnt > 0);

  always_ff @(posedge clk or negedge rst_n) begin: post_skp_add_128b130b_cnt_PROC
    if(!rst_n) begin
      post_skp_add_128b130b_cnt <= #`TP '0;
    end
    else if(estore_rd_sync_rst) begin
      post_skp_add_128b130b_cnt <= #`TP '0;
    end
    else if(!encdec_8b10b) begin
      if(rd_datavalid) begin
        // ccx_cond: ; 0; 01; "Possibly redundant condition due to PHY_NB value."
        if(skp_add_next_128b130b && done_skp_add_128b130b) begin
          post_skp_add_128b130b_cnt <= #`TP BLOCK_INT;
        end
        else if(post_skp_add_128b130b) begin
          if(symbol_width > BLOCK_INT) begin
            post_skp_add_128b130b_cnt <= #`TP '0;
          end
          else begin
            post_skp_add_128b130b_cnt <= #`TP $bits(post_skp_add_128b130b_cnt)'(post_skp_add_128b130b_cnt - symbol_width);
          end
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  SKP removing for 128b/130b encoding
// --------------------------------------------------------------------------------
  always_comb begin: skp_rem_sdata_128b130b_PROC
    logic [$clog2(BLOCK_NUM)-1:0]  l_ptr;
    logic                          l_skp_rem_next;
    skp_rem_sdata_128b130b = '0;
    for(int i = 0; i < (BLOCK_NUM / 2); i++) begin
      l_ptr = $bits(l_ptr)'(i + skp_rem_sdata_128b130b.num);
      l_skp_rem_next = 1'h0;
      if(symbol_width > (BLOCK_INT * i)) begin
        if(skpos_found_rem_128b130b[l_ptr]) begin
          skp_rem_sdata_128b130b.en = 1'h1;
          skp_rem_sdata_128b130b.num = $bits(skp_rem_sdata_128b130b.num)'(skp_rem_sdata_128b130b.num + 1);
          l_ptr = $bits(l_ptr)'(l_ptr + 1);
          l_skp_rem_next = 1'h1;
        end
        skp_rem_sdata_128b130b.data[i] = rd_sdata_128b130b[l_ptr];
        if(l_skp_rem_next) begin
          skp_rem_sdata_128b130b.data[i][0].hv = 1'h1;
          skp_rem_sdata_128b130b.data[i][0].hdr = SYNC_HDR_OS;
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  SKP adding for 1b/1b encoding
// --------------------------------------------------------------------------------
  struct packed {
    logic                                                      en;
    esdata_1b1b_t [(BLOCK_NUM_GEN6/2)-1:0][BLOCK_INT_GEN6-1:0] data;
    logic [$clog2((BLOCK_NUM_GEN6/2)+1)-1:0]                   num;
  }  skp_add_sdata_1b1b, skp_rem_sdata_1b1b;

  logic  skp_add_next_1b1b;

// spyglass disable_block W468
// SMD: Variable/signal which cannot index the full range of this vector.
// SJ: It is expected that 'l_ptr' only points to the first half part of 'rd_sdata_1b1b' and 'skpos_found_add_1b1b'.
// spyglass disable_block ImproperRangeIndex-ML
// SMD: Possible discrepancy in the range index or slice of an array
// SJ: The index 'l_ptr' never takes a value greater than the max value of the signal 'rd_sdata_1b1b' width
  always_comb begin: skp_add_sdata_1b1b_PROC
    logic [$clog2(BLOCK_NUM_GEN6/2)-1:0]  l_ptr;
    skp_add_sdata_1b1b = '0;
    skp_add_next_1b1b = 1'h0;
    for(int i = 0; i < (BLOCK_NUM_GEN6 / 2); i++) begin
      l_ptr = $bits(l_ptr)'(i - skp_add_sdata_1b1b.num);
      if(symbol_width > (BLOCK_INT_GEN6 * i)) begin
        skp_add_sdata_1b1b.data[i] = rd_sdata_1b1b[l_ptr];
        if(skp_add_next_1b1b) begin
          // ccx_line_begin: ; "Possibly redundant lines due to PHY_NB value."
          skp_add_sdata_1b1b.data[i][0].hv = 1'h0;
          skp_add_sdata_1b1b.data[i][0].hdr = '0;
          skp_add_next_1b1b = 1'h0;
          // ccx_line_end
        end
        else if(skpos_found_add_1b1b[l_ptr]) begin
          skp_add_sdata_1b1b.en = 1'h1;
          skp_add_sdata_1b1b.num = $bits(skp_add_sdata_1b1b.num)'(skp_add_sdata_1b1b.num + 1);
          skp_add_next_1b1b = 1'h1;
        end
      end
    end
  end
// spyglass enable_block ImproperRangeIndex-ML
// spyglass enable_block W468

  logic [$clog2(BLOCK_INT_GEN6+1)-1:0]  post_skp_add_1b1b_cnt;
  assign post_skp_add_1b1b = (post_skp_add_1b1b_cnt > 0);

  always_ff @(posedge clk or negedge rst_n) begin: post_skp_add_1b1b_cnt_PROC
    if(!rst_n) begin
      post_skp_add_1b1b_cnt <= #`TP '0;
    end
    else if(estore_rd_sync_rst) begin
      post_skp_add_1b1b_cnt <= #`TP '0;
    end
    else if(!encdec_8b10b) begin
      if(rd_datavalid) begin
        // ccx_cond: ; 0; 01; "Possibly redundant condition due to PHY_NB value."
        if(skp_add_next_1b1b && done_skp_add_1b1b) begin
          post_skp_add_1b1b_cnt <= #`TP BLOCK_INT_GEN6;
        end
        else if(post_skp_add_1b1b) begin
          if(symbol_width > BLOCK_INT_GEN6) begin
            post_skp_add_1b1b_cnt <= #`TP '0;
          end
          else begin
            post_skp_add_1b1b_cnt <= #`TP $bits(post_skp_add_1b1b_cnt)'(post_skp_add_1b1b_cnt - symbol_width);
          end
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  SKP removing for 1b/1b encoding
// --------------------------------------------------------------------------------
  always_comb begin: skp_rem_sdata_1b1b_PROC
    logic [$clog2(BLOCK_NUM_GEN6)-1:0]  l_ptr;
    logic                          l_skp_rem_next;
    skp_rem_sdata_1b1b = '0;
    for(int i = 0; i < (BLOCK_NUM_GEN6 / 2); i++) begin
      l_ptr = $bits(l_ptr)'(i + skp_rem_sdata_1b1b.num);
      l_skp_rem_next = 1'h0;
      if(symbol_width > (BLOCK_INT_GEN6 * i)) begin
        if(skpos_found_rem_1b1b[l_ptr]) begin
          skp_rem_sdata_1b1b.en = 1'h1;
          skp_rem_sdata_1b1b.num = $bits(skp_rem_sdata_1b1b.num)'(skp_rem_sdata_1b1b.num + 1);
          l_ptr = $bits(l_ptr)'(l_ptr + 1);
          l_skp_rem_next = 1'h1;
        end
        skp_rem_sdata_1b1b.data[i] = rd_sdata_1b1b[l_ptr];
        if(l_skp_rem_next) begin
          skp_rem_sdata_1b1b.data[i][0].hv = 1'h1;
          skp_rem_sdata_1b1b.data[i][0].hdr = SYNC_HDR_OS;
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  SKP added / removed data muxing
// --------------------------------------------------------------------------------
  always_comb begin: done_skp_add_8b10b_PROC
    done_skp_add_8b10b = 1'h0;
    done_skp_rem_8b10b = 1'h0;
    if(do_skp_add && skp_add_sdata_8b10b.en) begin
      done_skp_add_8b10b = 1'h1;
    end
    if(do_skp_rem && skp_rem_sdata_8b10b.en) begin
      done_skp_rem_8b10b = 1'h1;
    end
  end

  always_comb begin: done_skp_add_128b130b_PROC
    done_skp_add_128b130b = 1'h0;
    done_skp_rem_128b130b = 1'h0;
    if(do_skp_add && skp_add_sdata_128b130b.en) begin
      done_skp_add_128b130b = 1'h1;
    end
    if(do_skp_rem && skp_rem_sdata_128b130b.en) begin
      done_skp_rem_128b130b = 1'h1;
    end
  end

  always_comb begin: done_skp_add_1b1b_PROC
    done_skp_add_1b1b = 1'h0;
    done_skp_rem_1b1b = 1'h0;
    if(do_skp_add && skp_add_sdata_1b1b.en) begin
      done_skp_add_1b1b = 1'h1;
    end
    if(do_skp_rem && skp_rem_sdata_1b1b.en) begin
      done_skp_rem_1b1b = 1'h1;
    end
  end

  logic  done_skp_add, done_skp_rem;

  always_comb begin: done_skp_add_PROC
    done_skp_add = 1'h0;
    done_skp_rem = 1'h0;
    if(encdec_8b10b) begin
      done_skp_add = done_skp_add_8b10b;
      done_skp_rem = done_skp_rem_8b10b;
    end
    else if(pipe_rate inside {`GEN6_RATE}) begin
      done_skp_add = done_skp_add_1b1b;
      done_skp_rem = done_skp_rem_1b1b;
    end
    else begin
      done_skp_add = done_skp_add_128b130b;
      done_skp_rem = done_skp_rem_128b130b;
    end
  end

  esdata_8b10b_t [PHY_8B10B_NB-1:0]  skp_sdata_8b10b;

  always_comb begin: skp_sdata_8b10b_PROC
    skp_sdata_8b10b = $bits(skp_sdata_8b10b)'(rd_sdata_8b10b);
    if(done_skp_add_8b10b) begin
      skp_sdata_8b10b = $bits(skp_sdata_8b10b)'(skp_add_sdata_8b10b.data);
    end
    if(done_skp_rem_8b10b) begin
      skp_sdata_8b10b = $bits(skp_sdata_8b10b)'(skp_rem_sdata_8b10b.data);
    end
  end

  always_comb begin: skp_sdata_128b130b_PROC
    skp_sdata_128b130b = $bits(skp_sdata_128b130b)'(rd_sdata_128b130b);
    if(done_skp_add_128b130b) begin
      skp_sdata_128b130b = $bits(skp_sdata_128b130b)'(skp_add_sdata_128b130b.data);
    end
    if(done_skp_rem_128b130b) begin
      skp_sdata_128b130b = $bits(skp_sdata_128b130b)'(skp_rem_sdata_128b130b.data);
    end
  end

  esdata_1b1b_t [PHY_NB-1:0]  skp_sdata_1b1b;
  always_comb begin: skp_sdata_1b1b_PROC
    skp_sdata_1b1b = $bits(skp_sdata_1b1b)'(rd_sdata_1b1b);
    if(done_skp_add_1b1b) begin
      skp_sdata_1b1b = $bits(skp_sdata_1b1b)'(skp_add_sdata_1b1b.data);
    end
    if(done_skp_rem_1b1b) begin
      skp_sdata_1b1b = $bits(skp_sdata_1b1b)'(skp_rem_sdata_1b1b.data);
    end
  end

  struct packed {
    logic                    dv;
    logic [SYM_10B_WD-1:0]   data;
    logic                    hv;
    logic [SYNC_HDR_WD-1:0]  hdr;
    os_t                     os;
    logic                    err;
    logic                    os_corrected;
  } [PHY_NB-1:0]  skp_sdata;

  always_comb begin: skp_sdata_PROC
    skp_sdata = '0;
    if(encdec_8b10b) begin
      for(int i = 0; i < PHY_8B10B_NB; i++) begin
        skp_sdata[i].dv = skp_sdata_8b10b[i].dv;
        skp_sdata[i].data = skp_sdata_8b10b[i].data;
      end
    end
    else if(pipe_rate inside {`GEN6_RATE}) begin
      for(int i = 0; i < PHY_NB; i++) begin
        skp_sdata[i] = '{
          dv: skp_sdata_1b1b[i].dv,
          data: $bits(SYM_10B_WD)'(skp_sdata_1b1b[i].data),
          hv: skp_sdata_1b1b[i].hv,
          hdr: skp_sdata_1b1b[i].hdr,
          os: skp_sdata_1b1b[i].os,
          os_corrected: skp_sdata_1b1b[i].os_corrected,
          err: 1'b0
        };
      end
    end
    else begin
      for(int i = 0; i < PHY_NB; i++) begin
        skp_sdata[i] = '{
          dv: skp_sdata_128b130b[i].dv,
          data: $bits(SYM_10B_WD)'(skp_sdata_128b130b[i].data),
          hv: skp_sdata_128b130b[i].hv,
          hdr: skp_sdata_128b130b[i].hdr,
          os: skp_sdata_128b130b[i].os,
          os_corrected: '0,
          err: skp_sdata_128b130b[i].err
        };
      end
    end
  end

// --------------------------------------------------------------------------------
//  Next read pointer calculation
// --------------------------------------------------------------------------------
  always_comb begin: next_rd_ptr_8b10b_PROC
    next_rd_ptr_8b10b = rd_ptr;
    if(buf_almost_underflow_detected) begin
      next_rd_ptr_8b10b = rd_ptr;
    end
    else if(buf_almost_overflow_detected) begin
      next_rd_ptr_8b10b = calc_up_ptr_addr(rd_ptr, ADDR_WD'(symbol_width << 1));
    end
    else if(rd_datavalid) begin
      next_rd_ptr_8b10b = calc_up_ptr_addr(rd_ptr, ADDR_WD'(symbol_width));
      if(done_skp_add_8b10b) begin
        next_rd_ptr_8b10b = calc_up_ptr_addr(rd_ptr, ADDR_WD'(symbol_width - skp_add_sdata_8b10b.num));
      end
      if(done_skp_rem_8b10b) begin
        next_rd_ptr_8b10b = calc_up_ptr_addr(rd_ptr, ADDR_WD'(symbol_width + skp_rem_sdata_8b10b.num));
      end
    end
  end

  always_comb begin: next_rd_ptr_128b130b_PROC
    next_rd_ptr_128b130b = rd_ptr;
    if(buf_almost_underflow_detected) begin
      next_rd_ptr_128b130b = rd_ptr;
    end
    else if(buf_almost_overflow_detected) begin
      next_rd_ptr_128b130b = calc_up_ptr_addr(rd_ptr, ADDR_WD'(symbol_width << 1));
    end
    else if(rd_datavalid) begin
      next_rd_ptr_128b130b = calc_up_ptr_addr(rd_ptr, ADDR_WD'(symbol_width));
      if(done_skp_add_128b130b) begin
        if(symbol_width > BLOCK_INT) begin
          next_rd_ptr_128b130b = calc_up_ptr_addr(rd_ptr,
            ADDR_WD'(symbol_width - (skp_add_sdata_128b130b.num << $clog2(BLOCK_INT))));
        end
        else begin
          next_rd_ptr_128b130b = calc_down_ptr_addr(rd_ptr,
            ADDR_WD'((skp_add_sdata_128b130b.num << $clog2(BLOCK_INT)) - symbol_width));
        end
      end
      if(done_skp_rem_128b130b) begin
        next_rd_ptr_128b130b = calc_up_ptr_addr(rd_ptr,
          ADDR_WD'(symbol_width + (skp_rem_sdata_128b130b.num << $clog2(BLOCK_INT))));
      end
    end
  end

  always_comb begin: next_rd_ptr_1b1b_PROC
    next_rd_ptr_1b1b = rd_ptr;
    if(buf_almost_underflow_detected) begin
      next_rd_ptr_1b1b = rd_ptr;
    end
    else if(buf_almost_overflow_detected) begin
      next_rd_ptr_1b1b = calc_up_ptr_addr(rd_ptr, ADDR_WD'(symbol_width << 1));
    end
    else if(rd_datavalid) begin
      next_rd_ptr_1b1b = calc_up_ptr_addr(rd_ptr, ADDR_WD'(symbol_width));
      if(done_skp_add_1b1b) begin
        if(symbol_width > BLOCK_INT_GEN6) begin
          next_rd_ptr_1b1b = calc_up_ptr_addr(rd_ptr,
            ADDR_WD'(symbol_width - (skp_add_sdata_1b1b.num << $clog2(BLOCK_INT_GEN6))));
        end
        else begin
          next_rd_ptr_1b1b = calc_down_ptr_addr(rd_ptr,
            ADDR_WD'((skp_add_sdata_1b1b.num << $clog2(BLOCK_INT_GEN6)) - symbol_width));
        end
      end
      if(done_skp_rem_1b1b) begin
        next_rd_ptr_1b1b = calc_up_ptr_addr(rd_ptr,
          ADDR_WD'(symbol_width + (skp_rem_sdata_1b1b.num << $clog2(BLOCK_INT_GEN6))));
      end
    end
  end

// --------------------------------------------------------------------------------
//  Read data error dectection
// --------------------------------------------------------------------------------
  always_comb begin: invalid_rddata_found_PROC
    invalid_rddata_found = 1'h0;
    if(rd_datavalid) begin
      for(int i = 0; i < PHY_NB; i++) begin
        if(symbol_width > i) begin
          if(!skp_sdata[i].dv) begin
            invalid_rddata_found = 1'h1;
          end
        end
      end
    end
  end

  always_comb begin: err_rddata_found_PROC
    err_rddata_found = 1'h0;
    if(rd_datavalid) begin
      for(int i = 0; i < PHY_NB; i++) begin
        if(symbol_width > i) begin
          if(skp_sdata[i].err) begin
            err_rddata_found = 1'h1;
          end
        end
      end
    end
  end


// --------------------------------------------------------------------------------
//  Output data generation
// --------------------------------------------------------------------------------
  struct packed {
    logic                    valid;
    pipe_data_t              data;
    logic                    datavalid;
    logic                    mode;
    logic [PHY_RXSB_WD-1:0]  startblock;
    pipe_syncheader_t        syncheader;
    os_t  [PHY_RXSB_WD-1:0]  os;
    logic                    err_decode;
    logic                    os_corrected;
    logic                    sts_skp_add;
    logic                    sts_skp_rem;
    logic                    err_overflow;
    logic                    err_underflow;
  }  pre_estore_sdata, estore_sdata;

// spyglass disable_block AlwaysCombExhaustive-ML
// SMD: Not all conditions are covered for the combinational logic.
// SJ: A default value is defined to avoid a latch.
  always_comb begin: pre_estore_sdata_PROC
    pre_estore_sdata = '{
      valid: buf_halffull_rd_valid,
      datavalid: rd_datavalid,
      mode: buf_empty_mode,
      os: NONE,
      err_underflow: buf_almost_underflow_detected,
      err_overflow: buf_almost_overflow_detected,
      default: '0
    };
    if(!encdec_8b10b) begin
      if(startblock_found) begin
        pre_estore_sdata.valid = buf_halffull_rd_valid;
        pre_estore_sdata.datavalid = rd_datavalid;
      end
    end
    if(pre_estore_sdata.datavalid) begin
      pre_estore_sdata.sts_skp_add = done_skp_add;
      pre_estore_sdata.sts_skp_rem = done_skp_rem;
      pre_estore_sdata.err_decode = err_rddata_found;
      for(int i = 0; i < PHY_128B130B_NB; i++) begin
        if(symbol_width > i) begin
          pre_estore_sdata.data[i] = skp_sdata[i].data;
          if((i % BLOCK_INT) == 0) begin
            pre_estore_sdata.os[i/BLOCK_INT] = skp_sdata[i].os;
            pre_estore_sdata.startblock[i/BLOCK_INT] = skp_sdata[i].hv;
            pre_estore_sdata.syncheader[i/BLOCK_INT] = skp_sdata[i].hdr;
          end
        end
      end
      if(pipe_rate inside {`GEN6_RATE}) begin
        pre_estore_sdata.os = skp_sdata[0].os;
        pre_estore_sdata.os_corrected = skp_sdata[0].os_corrected;
        for(int i = 0; i < PHY_NB; i++) begin
          if(symbol_width > i) begin
            pre_estore_sdata.data[i] = skp_sdata[i].data;
            if((i % BLOCK_INT_GEN6) == 0) begin
              pre_estore_sdata.startblock[i/BLOCK_INT_GEN6] = skp_sdata[i].hv;
              pre_estore_sdata.syncheader[i/BLOCK_INT_GEN6] = skp_sdata[i].hdr;
            end
          end
        end
      end
    end
  end
// spyglass enable_block AlwaysCombExhaustive-ML

  always_comb begin: estore_sdata_PROC
    estore_rdvalid = 1'h0;
    estore_rddata = '0;
    estore_rddatavalid = 1'h0;
    estore_mode = 1'h0;
    estore_rxstartblock = '0;
    estore_rxsyncheader = '0;
    estore_os_found = NONE;
    err_128b130b_decode = 1'h0;
    estore_os_corrected = '0;
    sts_estore_skp_add = 1'h0;
    sts_estore_skp_rem = 1'h0;
    err_estore_overflow = 1'h0;
    err_estore_underflow = 1'h0;
    if(!estore_sync_rst) begin
      estore_rdvalid = estore_sdata.valid;
      estore_rddata = estore_sdata.data;
      estore_rddatavalid = estore_sdata.datavalid;
      estore_mode = estore_sdata.mode;
      estore_rxstartblock = estore_sdata.startblock;
      estore_rxsyncheader = estore_sdata.syncheader;
      estore_os_found = estore_sdata.os;
      err_128b130b_decode = estore_sdata.err_decode;
      estore_os_corrected = estore_sdata.os_corrected;
      sts_estore_skp_add = estore_sdata.sts_skp_add;
      sts_estore_skp_rem = estore_sdata.sts_skp_rem;
      err_estore_overflow = estore_sdata.err_overflow;
      err_estore_underflow = estore_sdata.err_underflow;
    end
  end

  delay_n
   #(
    .N(1),
    .WD($bits(pre_estore_sdata))
  ) u_delay_n (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .clear(estore_sync_rst),
    .din(pre_estore_sdata),
    // ------------- output ----------------
    .dout(estore_sdata)
  );





endmodule: serdes_pipe_rx_estore
