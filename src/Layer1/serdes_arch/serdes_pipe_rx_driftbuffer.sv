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
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_driftbuffer.sv#13 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side drift buffer module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_driftbuffer
  import serdes_pipe_pkg::*;
(
  // ---------- input (clk) --------------
  input logic                     clk,
  input logic                     rst_n,
  input logic                     dbuf_sync_rst,
  input logic                     sync_hdr_bypass_en,
  input logic                     low_ptr_en,
  input logic                     rcvry_lock_state,
  input logic                     deskew_en,
  input logic                     deskew_complete,
  input logic                     deskew_redo,
  input logic [PHY_SYM_WD-1:0]    symbol_width,
  input logic [PHY_RAW_WD-1:0]    raw_width,
  input logic                     encdec_128b130b,
  input logic                     encdec_1b1b,
  // ---------- input (rx_clk) -----------
  input logic                     rx_clk,
  input logic                     rx_rst_n,
  input logic                     dbuf_rx_sync_rst,
  input logic                     drift_buffer_en,
  input logic                     pipe_rxvalid,
  input logic                     block_aligned,
  input pipe_data128b_t           decoded_rxdata,
  input logic                     decoded_rxdatavalid,
  input logic [PHY_RXSB_WD-1:0]   decoded_rxstartblock,
  input pipe_syncheader_t         decoded_rxsyncheader,
  input os_t [PHY_RXSB_WD-1:0]    decoded_os_found,
  input logic                     eieos_found,
  input logic                     err_undef_skp,
  input logic                     encdec_1b1b_sync2rx,
  // ---------- output (clk) -------------
  output logic                    dbuf_rdvalid,
  output pipe_data128b_t          dbuf_rddata,
  output logic                    dbuf_rddatavalid,
  output logic [PHY_RXSB_WD-1:0]  dbuf_rxstartblock,
  output pipe_syncheader_t        dbuf_rxsyncheader,
  output os_t [PHY_RXSB_WD-1:0]   dbuf_os_found,
  output logic                    err_128b130b_decode,
  output logic                    deskew_aligned_to_unaligned,
  output logic                    deskew_aligned,
  output logic [7:0]              deskew_ptr,
  output logic                    deskew_avail,
  output logic                    deskew_req
);

// --------------------------------------------------------------------------------
//  Common internal parameter / type / function
// --------------------------------------------------------------------------------
  localparam int  DEPTH        = `CX_DRIFT_BUFFER_DEPTH;
  localparam int  ADDR_WD      = $clog2(DEPTH);
  localparam int  PTR_OFFSET   = ((2 ** ADDR_WD) - DEPTH) / 2;
  localparam int  DESKEW_DEPTH = `CX_DRIFT_BUFFER_DESKEW_DEPTH;
// -- Current implementation behave as Synchronizer depth is three when both SYNC_TYPE = 2 and 3. Will be supported latency reduced SYNC_TYPE=2
//  localparam int  INIT_PTR     = SYNC_TYPE - 1;
//  localparam int  UFLOW_DEPTH  = SYNC_TYPE;
//  localparam int  RD_STRAR_TH  = SYNC_TYPE - 1;
  localparam int  INIT_PTR     = 3 - 1;
  localparam int  UFLOW_DEPTH  = 3;
  localparam int  RD_STRT_PTR  = 3 - 1;
// ---
  localparam int  BCM_NMR      = 3; // BCM N-modular redundancy.
  localparam int  SB_CNT_WD    = $clog2(((SYM_WD * PHY_NB) / SYNC_HDR_WD) + PHY_RXSB_WD + 1);

  typedef struct packed {
    logic                    dv;
    pipe_data128b_t          data;
    logic [PHY_RXSB_WD-1:0]  startblock;
    pipe_syncheader_t        syncheader;
    logic                    err;
    logic                    deskew;
    os_t [PHY_RXSB_WD-1:0]   os;
  }  dbdata_128b130b_t;

  typedef struct packed {
    logic                    dv;
    pipe_data128b_t          data;
    logic [PHY_RXSB_WD-1:0]  startblock;
    pipe_syncheader_t        syncheader;
    logic                    deskew;
    os_t [PHY_RXSB_WD-1:0]   os;
    logic                    tmp;
  }  dbdata_1b1b_t;

  typedef struct packed {
    logic                    dv;
    pipe_data128b_t          data;
    logic [PHY_RXSB_WD-1:0]  startblock;
    pipe_syncheader_t        syncheader;
    logic                    deskew;
    os_t [PHY_RXSB_WD-1:0]   os;
  }  dbdata_cmn_t;

  typedef union packed {
    dbdata_128b130b_t        data_128b130b;
    dbdata_1b1b_t            data_1b1b;
  }  dbdata_u;

  function automatic logic [ADDR_WD-1:0]  calc_up_ptr (
    logic [ADDR_WD-1:0]  ptr,
    logic [ADDR_WD-1:0]  offset
  );
    logic [ADDR_WD-1:0]  ret;
    if(DEPTH > (ptr + offset)) begin
      ret = ADDR_WD'(ptr + offset);
    end
    else begin
      ret = ADDR_WD'(ptr + offset - DEPTH);
    end
    return ret;
  endfunction

  function automatic logic [ADDR_WD-1:0]  calc_down_ptr (
    logic [ADDR_WD-1:0]  ptr,
    logic [ADDR_WD-1:0]  offset
  );
    logic [ADDR_WD-1:0]  ret;
    if(ptr >= offset) begin
      ret = ADDR_WD'(ptr - offset);
    end
    else begin
      ret = ADDR_WD'(ptr + DEPTH - offset);
    end
    return ret;
  endfunction

// --------------------------------------------------------------------------------
//  Common internal signal (rx_clk)
// --------------------------------------------------------------------------------
  logic  dbuf_wr_sync_rst;
  logic  wr_sync_rst;
  assign dbuf_wr_sync_rst = dbuf_rx_sync_rst || wr_sync_rst;

  logic  rd_clk_running;
  logic  wr_valid;
  logic  wr_en;

  logic [ADDR_WD-1:0]  wr_ptr;

// --------------------------------------------------------------------------------
//  Common internal signal (clk)
// --------------------------------------------------------------------------------
  logic  dbuf_rd_sync_rst;
  logic  rd_sync_rst, rd_sync_rst_in_prog;
  assign dbuf_rd_sync_rst = dbuf_sync_rst || (rd_sync_rst || rd_sync_rst_in_prog);

  // Automotive requirement: cxl_auto_1.
  enum logic [2:0] {
    UNALIGNED = 'b001,
    ADJUSTING = 'b010,
    ALIGNED   = 'b100
  }  deskew_state, deskew_state_d, next_deskew_state;

  logic [ADDR_WD-1:0]  wr_ptr_sync, raw_wr_ptr_sync;
  assign wr_ptr_sync = ADDR_WD'(raw_wr_ptr_sync - PTR_OFFSET);

  logic [ADDR_WD-1:0]  rd_ptr;

  logic  rd_en;

// --------------------------------------------------------------------------------
//  Write control
// --------------------------------------------------------------------------------
  always_comb begin: wr_valid_PROC
    wr_valid = 1'h0;
    if(pipe_rxvalid) begin
      if(drift_buffer_en) begin
        if(rd_clk_running) begin
          wr_valid = (block_aligned) ? 1'h1 : 1'h0;
        end
      end
    end
  end

  logic  wr_in_prog;

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: wr_in_prog_PROC
    if(!rx_rst_n) begin
      wr_in_prog <= #`TP 1'h0;
    end
    else if(dbuf_wr_sync_rst || !wr_valid) begin
      wr_in_prog <= #`TP 1'h0;
    end
    else if(wr_en) begin
      wr_in_prog <= #`TP 1'h1;
    end
  end

  always_comb begin: wr_en_PROC
    wr_en = 1'h0;
    if(wr_valid) begin
      if(decoded_rxdatavalid) begin
        wr_en = 1'h1;
      end
    end
    else if(wr_in_prog) begin
      // Write an invalid data if wr_valid is de-asserted.
      wr_en = 1'h1;
    end
  end

// --------------------------------------------------------------------------------
//  BCM: pulse synchronizer with acknowledge (automotive-compliant)
// --------------------------------------------------------------------------------
  logic  ack_rd_clk_running;

  // Automotive requirement: cxl_auto_8. // use bcm23 because of the prefix issue
  DWC_pcie_ctl_bcm23
   #(
    .REG_EVENT(0),
    .REG_ACK(0),
    .ACK_DELAY(0),
    .F_SYNC_TYPE(SYNC_TYPE),
    .R_SYNC_TYPE(SYNC_TYPE),
    .VERIF_EN(1),
    .PULSE_MODE(1),
    .SVA_TYPE(0)
  ) u_DWC_pcie_ctl_bcm23 (
    // ---------- input (clk) --------------
    .clk_d(clk),
    .rst_d_n(rst_n),
    .init_d_n(1'h1),
    // ---------- input (rx_clk) -----------
    .clk_s(rx_clk),
    .rst_s_n(rx_rst_n),
    .init_s_n(1'h1),
    .event_s(pipe_rxvalid),
    // ---------- output (clk) -------------
    .event_d(),
    // ---------- output (rx_clk) ----------
    .ack_s(ack_rd_clk_running),
    .busy_s()
  );

  logic  int_rd_clk_running;
  assign rd_clk_running = ack_rd_clk_running || int_rd_clk_running;

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: int_rd_clk_running_PROC
    if(!rx_rst_n) begin
      int_rd_clk_running <= #`TP 1'h0;
    end
    else if(!pipe_rxvalid) begin
      int_rd_clk_running <= #`TP 1'h0;
    end
    else if(ack_rd_clk_running) begin
      int_rd_clk_running <= #`TP 1'h1;
    end
  end

// --------------------------------------------------------------------------------
//  Buffer with read data gating
// --------------------------------------------------------------------------------
  dbdata_u           wr_udata;

  always_comb begin: wr_udata_PROC
    wr_udata = '0;
    wr_udata.data_128b130b.dv         = wr_valid;
    wr_udata.data_128b130b.data       = decoded_rxdata;
    wr_udata.data_128b130b.startblock = decoded_rxstartblock;
    wr_udata.data_128b130b.syncheader = decoded_rxsyncheader;
    wr_udata.data_128b130b.err        = err_undef_skp;
    wr_udata.data_128b130b.deskew     = eieos_found;
    wr_udata.data_128b130b.os         = decoded_os_found;
    if (encdec_1b1b_sync2rx) begin
      wr_udata.data_1b1b.dv         = wr_valid;
      wr_udata.data_1b1b.data       = decoded_rxdata;
      wr_udata.data_1b1b.startblock = decoded_rxstartblock;
      wr_udata.data_1b1b.syncheader = decoded_rxsyncheader;
      wr_udata.data_1b1b.deskew     = 0; // Drift buffer deskew is not supported in Gen6
      wr_udata.data_1b1b.os         = decoded_os_found;
    end
  end

  dbdata_u           rd_udata;
  dbdata_cmn_t       rd_sdata;

  serdes_pipe_rx_subdriftbuffer
   #(
    .DEPTH(DEPTH),
    .ADDR_WD(ADDR_WD),
    .DATA_WD($bits(dbdata_128b130b_t))
  ) u_serdes_pipe_rx_subdriftbuffer (
    // ---------- input (clk) --------------
    .clk(clk),
    .rst_n(rst_n),
    .rd_en(rd_en),
    .rd_ptr(rd_ptr),
    // ---------- input (rx_clk) -----------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .rx_sync_rst(dbuf_wr_sync_rst),
    .wr_en(wr_en),
    .wr_ptr(wr_ptr),
    .wr_data(wr_udata),
    // ---------- output (clk) -------------
    .rd_data(rd_udata)
  );

  always_comb begin: rd_sdata_PROC
    rd_sdata.dv         = rd_udata.data_128b130b.dv;
    rd_sdata.data       = rd_udata.data_128b130b.data;
    rd_sdata.startblock = rd_udata.data_128b130b.startblock;
    rd_sdata.syncheader = rd_udata.data_128b130b.syncheader;
    rd_sdata.deskew     = rd_udata.data_128b130b.deskew;
    rd_sdata.os         = rd_udata.data_128b130b.os;
    if (encdec_1b1b) begin
      rd_sdata.dv         = rd_udata.data_1b1b.dv;
      rd_sdata.data       = rd_udata.data_1b1b.data;
      rd_sdata.startblock = rd_udata.data_1b1b.startblock;
      rd_sdata.syncheader = rd_udata.data_1b1b.syncheader;
      rd_sdata.deskew     = rd_udata.data_1b1b.deskew;
      rd_sdata.os         = rd_udata.data_1b1b.os;
    end
  end

// --------------------------------------------------------------------------------
//  BCM: reset synchronizer
// --------------------------------------------------------------------------------
  logic rd_sync_rst_in_prog_o ;
  logic rd_sync_rst_in_prog_o_d ;

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
    .clr_in_prog_d(rd_sync_rst_in_prog_o),
    .clr_sync_d(),
    .clr_cmplt_d(),
    // ---------- output (rx_clk) ----------
    .clr_sync_s(),
    .clr_in_prog_s(wr_sync_rst),
    .clr_cmplt_s()
  );

  always_ff @(posedge clk or negedge rst_n) begin: rd_sync_rst_in_prog_o_d_PROC
    if(!rst_n) begin
      rd_sync_rst_in_prog_o_d <= #`TP '0;
    end
    else begin
      rd_sync_rst_in_prog_o_d <= #`TP rd_sync_rst_in_prog_o ;
    end
  end

  always_comb begin : rd_sync_rst_in_prog_PROC
                         rd_sync_rst_in_prog   =  rd_sync_rst_in_prog_o ;
    if( SYNC_TYPE == 2 ) rd_sync_rst_in_prog   =  rd_sync_rst_in_prog_o | rd_sync_rst_in_prog_o_d ;
  end

// --------------------------------------------------------------------------------
//  BCM: gray coded synchronizer
// --------------------------------------------------------------------------------
  logic [ADDR_WD-1:0]  raw_wr_ptr_sync_o ;
  logic [ADDR_WD-1:0]  raw_wr_ptr_sync_o_d;

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
    .init_s_n(!dbuf_wr_sync_rst),
    .en_s(wr_en),
    // ---------- output (clk) -------------
    .count_d(raw_wr_ptr_sync_o),
    // ---------- output (rx_clk) ----------
    .count_s(),
    .offset_count_s(wr_ptr)
  );

  always_ff @(posedge clk or negedge rst_n) begin: raw_wr_ptr_sync_o_d_PROC
    if(!rst_n) begin
      raw_wr_ptr_sync_o_d <= #`TP PTR_OFFSET ;
    end
    else begin
      raw_wr_ptr_sync_o_d <= #`TP raw_wr_ptr_sync_o ;
    end
  end

  always_comb begin : raw_wr_ptr_sync_PROC
                         raw_wr_ptr_sync   =  raw_wr_ptr_sync_o ;
    if( SYNC_TYPE == 2 ) raw_wr_ptr_sync   =  raw_wr_ptr_sync_o_d ;
  end
  
// --------------------------------------------------------------------------------
//  Read control
// --------------------------------------------------------------------------------
  logic  do_rd_start;
  logic  rd_in_prog;
  logic  int_sync_hdr_bypass_en;

  assign int_sync_hdr_bypass_en = sync_hdr_bypass_en || encdec_1b1b;

  always_comb begin: do_rd_start_PROC
    do_rd_start = (int_sync_hdr_bypass_en) ? (wr_ptr_sync > 0) : (wr_ptr_sync > RD_STRT_PTR);
    if(rd_in_prog) begin
      do_rd_start = 1'h0;
    end
  end

  always_comb begin: rd_en_PROC
    rd_en = 1'h0;
    if(!(dbuf_sync_rst || rd_sync_rst_in_prog)) begin
      rd_en = do_rd_start || rd_in_prog;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin: rd_in_prog_PROC
    if(!rst_n) begin
      rd_in_prog <= #`TP 1'h0;
    end
    else if(dbuf_rd_sync_rst) begin
      rd_in_prog <= #`TP 1'h0;
    end
    else if(do_rd_start) begin
      rd_in_prog <= #`TP 1'h1;
    end
  end

  logic  rd_valid;
  logic  rd_deadcycle;

  always_comb begin: rd_valid_PROC
    rd_valid = 1'h0;
    if(rd_en) begin
      rd_valid = 1'h1;
      if(!int_sync_hdr_bypass_en) begin
        if(rd_deadcycle) begin
          rd_valid = 1'h0;
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  De-skew counter
// --------------------------------------------------------------------------------
  logic [$clog2(DESKEW_DEPTH+1)-1:0]  deskew_cnt, next_deskew_cnt;
  logic                               deskew_cnt_expired;
  assign deskew_cnt_expired = (deskew_cnt == $bits(deskew_cnt)'(DESKEW_DEPTH));

  always_ff @(posedge clk or negedge rst_n) begin: deskew_cnt_PROC
    if(!rst_n) begin
      deskew_cnt <= #`TP '0;
    end
    else if(dbuf_rd_sync_rst || !deskew_en || deskew_redo) begin
      deskew_cnt <= #`TP '0;
    end
    else begin
      deskew_cnt <= #`TP next_deskew_cnt;
    end
  end

  always_comb begin: next_deskew_cnt_PROC
    next_deskew_cnt = deskew_cnt;
    if(deskew_avail) begin
      if(!deskew_complete) begin
        if(deskew_cnt_expired) begin
          next_deskew_cnt = '0;
        end
        else if(rd_valid) begin
          next_deskew_cnt = $bits(next_deskew_cnt)'(deskew_cnt + 1);
        end
      end
      // For the case that deadcycle is comming at the timing deskew is completed
      else if(!rd_valid) begin 
        next_deskew_cnt = $bits(next_deskew_cnt)'(deskew_cnt - 1);
      end
    end
    else if(deskew_state == UNALIGNED) begin
      next_deskew_cnt = '0;
    end
  end

  logic [7:0] pre_deskew_ptr;
  always_comb begin: pre_deskew_ptr_PROC
    pre_deskew_ptr = '0;
    if(deskew_en) begin
      if(deskew_state == ALIGNED) begin
        pre_deskew_ptr = $bits(pre_deskew_ptr)'(deskew_cnt);
      end
    end
  end

// --------------------------------------------------------------------------------
//  De-skew FSM
// --------------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin: deskew_state_PROC
    if(!rst_n) begin
      deskew_state <= #`TP UNALIGNED;
    end
    else if(dbuf_rd_sync_rst || !deskew_en || deskew_redo) begin
      deskew_state <= #`TP UNALIGNED;
    end
    else begin
      deskew_state <= #`TP next_deskew_state;
    end
  end

  always_comb begin: next_deskew_state_PROC
    next_deskew_state = deskew_state;
    case(deskew_state)
      UNALIGNED: begin
        if(deskew_avail) begin
          if(deskew_complete) begin
            next_deskew_state = ALIGNED;
          end
          else begin
            next_deskew_state = ADJUSTING;
          end
        end
      end
      ADJUSTING: begin
        if(deskew_complete) begin
          next_deskew_state = ALIGNED;
        end
        else if(deskew_cnt_expired) begin
          next_deskew_state = UNALIGNED;
        end
      end
      ALIGNED: next_deskew_state = ALIGNED;
      // Automotive requirement: cxl_auto_1.
      default: next_deskew_state = UNALIGNED;
    endcase
  end

// --------------------------------------------------------------------------------
//  Read pointer
// --------------------------------------------------------------------------------
  logic [ADDR_WD-1:0]  raw_rd_ptr, raw_low_rd_ptr;

  always_ff @(posedge clk or negedge rst_n) begin: raw_rd_ptr_PROC
    if(!rst_n) begin
      raw_rd_ptr <= #`TP ADDR_WD'(INIT_PTR);
      raw_low_rd_ptr <= #`TP ADDR_WD'(INIT_PTR - 1);
   end
    else if(dbuf_rd_sync_rst) begin
      raw_rd_ptr <= #`TP ADDR_WD'(INIT_PTR);
      raw_low_rd_ptr <= #`TP ADDR_WD'(INIT_PTR - 1);
    end
    else if(rd_valid) begin
      raw_rd_ptr <= #`TP calc_up_ptr(raw_rd_ptr, ADDR_WD'(1));
      raw_low_rd_ptr <= #`TP calc_up_ptr(raw_low_rd_ptr, ADDR_WD'(1));
    end
  end
  
  always_comb begin: rd_ptr_PROC
    rd_ptr = (low_ptr_en) ? raw_low_rd_ptr : raw_rd_ptr;
    if(deskew_en) begin
      if(deskew_state == ALIGNED) begin
        rd_ptr = calc_down_ptr(rd_ptr, ADDR_WD'(deskew_cnt));
      end
    end
  end

// --------------------------------------------------------------------------------
//  Dead cycle control
// --------------------------------------------------------------------------------
  logic [$clog2(PHY_RXSB_WD+1)-1:0]  rd_startblock_num;

  always_comb begin: rd_startblock_num_PROC
    rd_startblock_num = '0;
    for(int i = 0; i < PHY_RXSB_WD; i++) begin
      if(rd_sdata.startblock[i]) begin
        rd_startblock_num = $bits(rd_startblock_num)'(rd_startblock_num + 1);
      end
    end
  end

  logic [SB_CNT_WD-1:0]  startblock_cnt, max_startblock_cnt;
  logic                  startblock_cnt_expired;
  logic                  deskew_rxvalid_align;
  logic                  deskew_unaligned_to_aligned;

  assign max_startblock_cnt = SB_CNT_WD'(raw_width >> $clog2(SYNC_HDR_WD));
  assign rd_deadcycle = startblock_cnt_expired || deskew_unaligned_to_aligned;

  always_ff @(posedge clk or negedge rst_n) begin: startblock_cnt_PROC
    if(!rst_n) begin
      startblock_cnt <= #`TP '0;
    end
    else if(dbuf_rd_sync_rst || int_sync_hdr_bypass_en) begin
      startblock_cnt <= #`TP '0;
    end
    else if(rd_en) begin
      if(deskew_rxvalid_align) begin
        startblock_cnt <= #`TP '0;
      end   
      else if(startblock_cnt_expired) begin
        startblock_cnt <= #`TP $bits(startblock_cnt)'(startblock_cnt - max_startblock_cnt);
      end
      else begin
        startblock_cnt <= #`TP $bits(startblock_cnt)'(startblock_cnt + rd_startblock_num);
      end
    end
  end

  always_comb begin: startblock_cnt_expired_PROC
    if(startblock_cnt == max_startblock_cnt) begin
      startblock_cnt_expired = (rd_startblock_num > 0);
    end
    else begin
      startblock_cnt_expired = (startblock_cnt > max_startblock_cnt);
    end
  end

// --------------------------------------------------------------------------------
//  Read error detection / Read clear
// --------------------------------------------------------------------------------
  logic  invalid_rddata_found;
  logic  err_rddata_found;

  always_comb begin: invalid_rddata_found_PROC
    invalid_rddata_found = 1'h0;
    err_rddata_found = 1'h0;
    if(rd_valid) begin
      invalid_rddata_found = !rd_sdata.dv;
      err_rddata_found = rd_udata.data_128b130b.err && encdec_128b130b;
    end
  end

  logic  buf_underflow_detected;

  always_comb begin: buf_underflow_detected_PROC
    buf_underflow_detected = 1'h0;
    if(rd_valid) begin
      buf_underflow_detected = (calc_up_ptr(wr_ptr_sync, ADDR_WD'(UFLOW_DEPTH)) == rd_ptr);
    end
  end

  always_comb begin: rd_sync_rst_PROC
    rd_sync_rst = 1'h0;
    if(rd_valid) begin
      rd_sync_rst = (invalid_rddata_found || err_rddata_found || buf_underflow_detected);
    end
  end

// --------------------------------------------------------------------------------
// Rxvalid de-assertion for Deskew 
//  -When the deskew state transitions, rxvalid is de-asserted until next startblock.
//  -When current LTSSM state is RCVRY.LOCK, rxvalid is de-asserted until deskew is aligned.
// --------------------------------------------------------------------------------
  logic  deskew_unaligned_in_rcvry_lock;
  logic  deskew_release_wait;
  logic  rxvalid_align;
  assign deskew_unaligned_in_rcvry_lock = (deskew_en && (deskew_state != ALIGNED) && rcvry_lock_state);
  assign deskew_unaligned_to_aligned = (deskew_state == ALIGNED) && ((deskew_state_d == UNALIGNED) || (deskew_state_d == ADJUSTING));
  assign deskew_aligned_to_unaligned = (deskew_state == UNALIGNED) && (deskew_state_d == ALIGNED);
  assign deskew_aligned = (deskew_state == ALIGNED);

  always_ff @(posedge clk or negedge rst_n) begin: deskew_state_d_PROC
    if(!rst_n) begin
      deskew_state_d <= #`TP UNALIGNED;
    end
    else begin
      deskew_state_d <= #`TP deskew_state;
    end
  end

// RxValid is deasserted for minimum 16 cycles by this counter.
// If short deassertion happens, freq_step / rmlh_deskew don't work well.
  logic [7:0] tmp_cnt;
  logic       tmp_cnt_expired;
  logic       rxvalid_mask, rxvalid_mask_d;

  assign tmp_cnt_expired = (tmp_cnt == 'hF);
  assign rxvalid_mask = rxvalid_mask_d || deskew_unaligned_to_aligned || deskew_aligned_to_unaligned;

  always_ff @(posedge clk or negedge rst_n) begin: tmp_cnt_PROC
    if(!rst_n) begin
      tmp_cnt <= #`TP '0;
    end
    else if(dbuf_rd_sync_rst) begin
      tmp_cnt <= #`TP '0;
    end
    else if(rxvalid_mask) begin
      tmp_cnt <= #`TP (tmp_cnt_expired) ? '0 : $bits(tmp_cnt)'(tmp_cnt + 1);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin: rxvalid_mask_d_PROC
    if(!rst_n) begin
      rxvalid_mask_d <= #`TP 1'h0;
    end
    else if(dbuf_rd_sync_rst) begin
      rxvalid_mask_d <= #`TP 1'h0;
    end
    else if(deskew_unaligned_to_aligned || deskew_aligned_to_unaligned) begin
      rxvalid_mask_d <= #`TP 1'h1;
    end
    else if(tmp_cnt_expired || !rd_en) begin
      rxvalid_mask_d <= #`TP 1'h0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin: rxvalid_align_PROC
    if(!rst_n) begin
      rxvalid_align <= #`TP 1'h0;
    end
    else if(dbuf_rd_sync_rst) begin
      rxvalid_align <= #`TP 1'h0;
    end
    else if(deskew_unaligned_to_aligned || deskew_aligned_to_unaligned) begin
      rxvalid_align <= #`TP 1'h1;
    end
    else if((!rxvalid_mask && |rd_sdata.startblock) || !rd_en) begin
      rxvalid_align <= #`TP 1'h0;
    end
  end

  always_comb begin: deskew_rxvalid_align_PROC
    deskew_rxvalid_align = rxvalid_align;
    if(deskew_unaligned_to_aligned || deskew_aligned_to_unaligned) begin
      deskew_rxvalid_align = 1'h1;
    end
    else if(!rxvalid_mask && |rd_sdata.startblock) begin
      deskew_rxvalid_align = 1'h0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin: deskew_release_wait_PROC
    if(!rst_n) begin
      deskew_release_wait <= #`TP 1'h0;
    end
    else if(dbuf_rd_sync_rst || int_sync_hdr_bypass_en) begin
      deskew_release_wait <= #`TP 1'h0;
    end
    else begin
      if(deskew_aligned_to_unaligned) begin
        deskew_release_wait <= #`TP 1'h1;
      end
      else if (!rd_en) begin
        deskew_release_wait <= #`TP 1'h0;
      end
    end
  end

// --------------------------------------------------------------------------------
//  Data output
// --------------------------------------------------------------------------------

  always_comb begin: dbuf_rdvalid_PROC
    dbuf_rdvalid = 1'h0;
    dbuf_rddatavalid = 1'h0;
    if(!invalid_rddata_found && !deskew_unaligned_in_rcvry_lock && !deskew_rxvalid_align && !deskew_release_wait) begin
      dbuf_rdvalid = rd_en;
      dbuf_rddatavalid = rd_valid;
    end
  end

  always_comb begin: dbuf_rddata_PROC
    dbuf_rddata = '0;
    dbuf_rxstartblock = '0;
    dbuf_rxsyncheader = '0;
    err_128b130b_decode = 1'h0;
    dbuf_os_found = NONE;
    if(dbuf_rddatavalid) begin
      dbuf_os_found = rd_sdata.os;
      if (encdec_128b130b) err_128b130b_decode = rd_udata.data_128b130b.err;
      for(int i = 0; i < PHY_NB; i++) begin
        if(symbol_width > i) begin
          dbuf_rddata[i] = rd_sdata.data[i];
          if((i % BLOCK_INT_GEN6) == 0) begin
            dbuf_rxstartblock[i/BLOCK_INT_GEN6] = rd_sdata.startblock[i/BLOCK_INT_GEN6];
            dbuf_rxsyncheader[i/BLOCK_INT_GEN6] = rd_sdata.syncheader[i/BLOCK_INT_GEN6];
          end
        end
      end
    end
  end

// --------------------------------------------------------------------------------
//  De-skew output
// --------------------------------------------------------------------------------
  always_comb begin: deskew_avail_PROC
    deskew_avail = 1'h0;
    if(deskew_en) begin
      case(deskew_state)
        UNALIGNED: begin
          if(rd_valid) begin
            if(rd_sdata.deskew) begin
              deskew_avail = 1'h1;
            end
          end
        end
        ADJUSTING: deskew_avail = 1'h1;
        default: deskew_avail = 1'h0;
      endcase
    end
  end

  always_comb begin: deskew_req_PROC
    deskew_req = 1'h0;
    if(deskew_en) begin
      deskew_req = (deskew_state != ALIGNED);
    end
  end

  delay_n
   #(
    .N(1),
    .WD($bits(pre_deskew_ptr)),
    .RESETVAL('0)
  ) u_delay_n_deskew_ptr (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .clear(1'h0),
    .din(pre_deskew_ptr),
    // ------------- output ----------------
    .dout(deskew_ptr)
  );

endmodule: serdes_pipe_rx_driftbuffer
