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
// ---    $DateTime: 2024/01/03 02:06:32 $
// ---    $Revision: #21 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx.sv#21 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side top module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx

  import serdes_pipe_pkg::*;
(
  // ------------- input -----------------
  input logic                        clk,
  input logic                        rst_n,
  input logic                        rx_clk,
  input logic                        rx_rst_n,
  input logic                        sync_hdr_bypass_en,
  input logic                        rcvry_lock_state,
  input logic                        drift_buffer_en,
  input logic                        drift_buffer_low_ptr_en,
  input logic                        deskew_en,
  input logic                        deskew_complete,
  input logic                        deskew_redo,
  input logic [9:0]                  skpos_interval_block_num,
  input logic                        loopback_state,
  input logic                        poll_compliance_state,
  input logic                        encdec_8b10b,
  input logic [RATE_WD-1:0]          pipe_rate,
  input logic [WIDTH_WD-1:0]         pipe_width,
  input logic                        pipe_srisen,
  input logic                        flit_mode_enable,
  input logic [SERDES_DATA_WD-1:0]   serdes_pipe_rxdata,
  input logic                        serdes_pipe_rxvalid,
  input logic [2:0]                  serdes_pipe_rxstatus,
  input logic                        serdes_pipe_txdetectrx,
  input logic                        orig_pipe_loopback_slave,
  input logic                        orig_pipe_rxpolarity,
  input logic                        orig_pipe_blockaligncontrol,
  input logic                        orig_pipe_elasticbuffermode,
  // ------------- output ----------------
  output logic [7:0]                 deskew_ptr,
  output logic                       deskew_avail,
  output logic                       deskew_aligned,
  output logic                       deskew_req,
  output logic                       os_corrected,
  output logic [SERDES_DATA_WD-1:0]  loopback_rxdata,
  output logic                       loopback_rxdatavalid,
  output logic [PHY_RXSB_WD-1:0]     loopback_rxstartblock,
  output logic [PHY_RXSH_WD-1:0]     loopback_rxsyncheader,
  output logic [ORIG_DATA_WD-1:0]    orig_pipe_rxdata,
  output logic [PHY_NB-1:0]          orig_pipe_rxdatak,
  output logic                       orig_pipe_rxvalid,
  output logic                       orig_pipe_rxdatavalid,
  output logic [PHY_RXSB_WD-1:0]     orig_pipe_rxstartblock,
  output logic [PHY_RXSH_WD-1:0]     orig_pipe_rxsyncheader,
  output os_found_t                  orig_pipe_os_found,
  output logic [PHY_RXSB_WD-1:0]     orig_pipe_os_found_end,
  output logic [2:0]                 orig_pipe_rxstatus,
  output logic                       serdes_pipe_rxready
);

// --------------------------------------------------------------------------------
//  Common internal parameter / enum / function
// --------------------------------------------------------------------------------
  localparam int  LOCK_BUF_WD   = $bits(pipe_data10b_t) + SYM_10B_WD - 2;
  localparam int  ALIGN_BUF_WD  = BLOCK_WD - 1;
  localparam int  DECODE_BUF_WD = $bits(pipe_data128b_t) + $bits(pipe_syncheader_t) - 1;
  localparam int  BYPASS_BUF_WD = $bits(pipe_data128b_t) - 1;
  localparam int  RXDATA_BUF_WD = get_rxdata_buf_width();

  // This "PTR_WD" is there to avoid the Spyglass ImproperRangeIndex-ML 
  localparam int PTR_WD = $clog2(RXDATA_BUF_WD+$bits(pipe_data128b_t));

  typedef enum logic [2:0] {
    RXSTAT_DATA_OK    = 3'b000, // Receiver not present
    RXSTAT_SKP_ADD    = 3'b001,
    RXSTAT_SKP_REM    = 3'b010,
    RXSTAT_RX_DET     = 3'b011, // Receiver present
    RXSTAT_DEC_ERR    = 3'b100,
    RXSTAT_EBUF_OFLOW = 3'b101,
    RXSTAT_EBUF_UFLOW = 3'b110,
    RXSTAT_DISP_ERR   = 3'b111
  }  rxstatus_t;

  function automatic int  get_rxdata_buf_width ();
    int  ret;
    ret = LOCK_BUF_WD;
    ret = (ret > ALIGN_BUF_WD) ? ret : ALIGN_BUF_WD;
    ret = (ret > DECODE_BUF_WD) ? ret : DECODE_BUF_WD;
    ret = (ret > BYPASS_BUF_WD) ? ret : BYPASS_BUF_WD;
    return ret;
  endfunction

// --------------------------------------------------------------------------------
//  Common internal signal (rx_clk)
// --------------------------------------------------------------------------------
  pipe_data_t                   raw_rxdata, pre_regin_rxdata, regin_rxdata;
  logic                         raw_rxvalid, pre_regin_rxvalid, regin_rxvalid, muxed_rxvalid;
  logic                         rx_sync_rst, raw_rx_sync_rst, muxed_rx_sync_rst;
  logic                         sync_hdr_bypass_en_sync2rx;
  logic                         drift_buffer_en_sync2rx;
  logic [9:0]                   skpos_interval_block_num_sync2rx;
  logic                         loopback_state_sync2rx;
  logic                         poll_compliance_state_sync2rx;
  logic                         pipe_srisen_sync2rx;
  logic                         flit_mode_enable_sync2rx;
  logic                         encdec_128b130b;
  logic                         encdec_1b1b;
  logic                         encdec_1b1b_sync2rx;
  logic                         encdec_8b10b_sync2rx;
  logic [PHY_SYM_WD-1:0]        symbol_width_sync2rx;
  logic [PHY_8B10B_SYM_WD-1:0]  symbol_width_8b10b_sync2rx;
  logic [PHY_RAW_WD-1:0]        raw_width_sync2rx;
  logic [PHY_10B_RAW_WD-1:0]    raw_width_8b10b_sync2rx;
  logic [RATE_WD-1:0]           pipe_rate_sync2rx;
  logic [WIDTH_WD-1:0]          pipe_width_sync2rx;
  logic                         pipe_loopback_slave_sync2rx;
  logic                         pipe_rxpolarity_sync2rx;
  logic                         pipe_blockaligncontrol_sync2rx;
  logic                         err_estore_overflow_sync2rx;
  logic                         err_estore_underflow_sync2rx;
  logic                         deskew_aligned_to_unaligned;
  logic                         deskew_aligned_to_unaligned_sync2rx;
  logic                         low_latency_ctrl_en_sync2rx;

  assign raw_rxdata = serdes_pipe_rxdata;
  assign raw_rxvalid = serdes_pipe_rxvalid;
  assign rx_sync_rst = !regin_rxvalid || raw_rx_sync_rst;
  assign muxed_rx_sync_rst = !muxed_rxvalid || raw_rx_sync_rst;
  assign encdec_8b10b_sync2rx = (pipe_rate_sync2rx inside {`GEN1_RATE, `GEN2_RATE});
  assign encdec_128b130b = (pipe_rate inside {`GEN3_RATE, `GEN4_RATE, `GEN5_RATE});
  assign encdec_1b1b = (pipe_rate inside {`GEN6_RATE});
  assign encdec_1b1b_sync2rx = (pipe_rate_sync2rx inside {`GEN6_RATE});
  assign symbol_width_sync2rx = get_symbol_width(pipe_width_sync2rx);
  assign symbol_width_8b10b_sync2rx = $bits(symbol_width_8b10b_sync2rx)'(symbol_width_sync2rx);
  assign raw_width_sync2rx = $bits(raw_width_sync2rx)'(get_raw_width(pipe_width_sync2rx, 1'h0));
  assign raw_width_8b10b_sync2rx = $bits(raw_width_8b10b_sync2rx)'(get_raw_width(pipe_width_sync2rx, 1'h1));
 // Enables low latency data path
  assign low_latency_ctrl_en_sync2rx = sync_hdr_bypass_en_sync2rx || encdec_1b1b_sync2rx;

  always_comb begin: muxed_rxvalid_PROC
    muxed_rxvalid = regin_rxvalid;
    if(low_latency_ctrl_en_sync2rx) begin
      muxed_rxvalid = raw_rxvalid;
    end
  end

// --------------------------------------------------------------------------------
//  Common internal signal (clk)
// --------------------------------------------------------------------------------
  logic                         buf_sync_rst;
  logic [PHY_SYM_WD-1:0]        symbol_width;
  logic [PHY_8B10B_SYM_WD-1:0]  symbol_width_8b10b;
  logic [PHY_RAW_WD-1:0]        raw_width;
  assign symbol_width = get_symbol_width(pipe_width);
  assign symbol_width_8b10b = $bits(symbol_width_8b10b)'(symbol_width);
  assign raw_width = $bits(raw_width)'(get_raw_width(pipe_width, 1'h0));

// --------------------------------------------------------------------------------
//  Registered input signal (rx_clk)
// --------------------------------------------------------------------------------
  delay_n
   #(
    .N(1),
    .WD($bits({raw_rxdata, raw_rxvalid})),
    .RESETVAL('0)
  ) u_delay_n_rx_clk_regin (
    // ------------- input -----------------
    .clk(rx_clk),
    .rst_n(rx_rst_n),
    .clear(1'h0),
    .din({raw_rxdata, raw_rxvalid}),
    // ------------- output ----------------
    .dout({pre_regin_rxdata, pre_regin_rxvalid})
  );

// --------------------------------------------------------------------------------
//  Polarity inversion
// --------------------------------------------------------------------------------
  pipe_data_t  pre_inv_regin_rxdata, inv_regin_rxdata;
  assign pre_inv_regin_rxdata = (pipe_rxpolarity_sync2rx) ? ~pre_regin_rxdata : pre_regin_rxdata;

// Pipeline for the gen6 FPGA to reduce the route delay on inv_regin_rxdata
  delay_n
   #(
    .N(0),
    .WD($bits({pre_inv_regin_rxdata, pre_regin_rxvalid})),
    .RESETVAL('0)
  ) u_delay_n_inv_regin_data (
    // ------------- input -----------------
    .clk(rx_clk),
    .rst_n(rx_rst_n),
    .clear(1'h0),
    .din({pre_inv_regin_rxdata, pre_regin_rxvalid}),
    // ------------- output ----------------
    .dout({inv_regin_rxdata, regin_rxvalid})
  );

  pipe_data10b_t  inv_regin_rxdata_8b10b;
  assign inv_regin_rxdata_8b10b = $bits(inv_regin_rxdata_8b10b)'(inv_regin_rxdata);

  pipe_data_t  inv_raw_rxdata;
  assign inv_raw_rxdata = (pipe_rxpolarity_sync2rx) ? ~raw_rxdata : raw_rxdata;

  pipe_data128b_t  inv_raw_rxdata_128b130b;

  always_comb begin: inv_raw_rxdata_128b130b_PROC
    inv_raw_rxdata_128b130b = '0;
    for(int i = 0; i < PHY_NB; i++) begin
      inv_raw_rxdata_128b130b[i] = inv_raw_rxdata[i][SYM_WD-1:0];
    end
  end

  pipe_data128b_t  inv_regin_rxdata_128b130b;

  always_comb begin: inv_regin_rxdata_128b130b_PROC
    inv_regin_rxdata_128b130b = '0;
    for(int i = 0; i < PHY_NB; i++) begin
      inv_regin_rxdata_128b130b[i] = inv_regin_rxdata[i][SYM_WD-1:0];
    end
  end

  pipe_data128b_t  muxed_inv_rxdata_128b130b;

  always_comb begin: muxed_inv_rxdata_128b130b_PROC
    muxed_inv_rxdata_128b130b = inv_regin_rxdata_128b130b;
    if(low_latency_ctrl_en_sync2rx) begin
      muxed_inv_rxdata_128b130b = inv_raw_rxdata_128b130b;
    end
  end

// --------------------------------------------------------------------------------
//  RxData buffer
// --------------------------------------------------------------------------------
  logic [RXDATA_BUF_WD-1:0]  buf_rxdata;
  logic [RXDATA_BUF_WD-1:0]  pre_buf_rxdata_8b10b;

  always_comb begin: pre_buf_rxdata_8b10b_PROC
    logic [RXDATA_BUF_WD+$bits(pipe_data10b_t)-1:0]  l_rxdata;
    l_rxdata = {inv_regin_rxdata_8b10b, buf_rxdata};
    pre_buf_rxdata_8b10b = l_rxdata[raw_width_8b10b_sync2rx+RXDATA_BUF_WD-1-:RXDATA_BUF_WD];
  end

  logic [RXDATA_BUF_WD-1:0]  pre_buf_rxdata_128b130b;

  always_comb begin: pre_buf_rxdata_128b130b_PROC
    logic [RXDATA_BUF_WD+$bits(pipe_data128b_t)-1:0]  l_rxdata;
    logic [PTR_WD-1:0]                                l_ptr;
    l_rxdata = {muxed_inv_rxdata_128b130b, buf_rxdata};
    l_ptr = $bits(l_ptr)'(raw_width_sync2rx+RXDATA_BUF_WD-1);
    pre_buf_rxdata_128b130b = l_rxdata[l_ptr-:RXDATA_BUF_WD];
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin
    if(!rx_rst_n) begin
      buf_rxdata <= #`TP '0;
    end
    else if(muxed_rx_sync_rst) begin
      buf_rxdata <= #`TP '0;
    end
    else begin
      if(encdec_8b10b_sync2rx) begin
        buf_rxdata <= #`TP pre_buf_rxdata_8b10b;
      end
      else begin
        buf_rxdata <= #`TP pre_buf_rxdata_128b130b;
      end
    end
  end

// --------------------------------------------------------------------------------
//  Symbol lock
// --------------------------------------------------------------------------------
  logic [LOCK_BUF_WD-1:0]  buf_lock_rxdata;
  logic                    eios_found_8b10b;
  logic                    symbol_locked;
  pipe_data10b_t           locked_rxdata;
  assign buf_lock_rxdata = buf_rxdata[RXDATA_BUF_WD-1-:LOCK_BUF_WD];

  serdes_pipe_rx_symbollock
   #(
    .BUF_WD(LOCK_BUF_WD)
  )  u_serdes_pipe_rx_symbollock (
  // ------------- input -----------------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .rx_sync_rst(rx_sync_rst),
    .encdec_8b10b(encdec_8b10b_sync2rx),
    .raw_width(raw_width_8b10b_sync2rx),
    .pipe_rxdata(inv_regin_rxdata_8b10b),
    .buf_rxdata(buf_lock_rxdata),
    .pipe_loopback_slave(pipe_loopback_slave_sync2rx),
    .eios_found(eios_found_8b10b),
  // ------------- output ----------------
    .symbol_locked(symbol_locked),
    .locked_rxdata(locked_rxdata)
  );

  serdes_pipe_rx_8b10b_osfind
    u_serdes_pipe_rx_8b10b_osfind (
  // ------------- input -----------------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .rx_sync_rst(rx_sync_rst),
    .symbol_width(symbol_width_8b10b_sync2rx),
    .symbol_locked(symbol_locked),
    .locked_rxdata(locked_rxdata),
  // ------------- output ----------------
    .eios_found(eios_found_8b10b)
  );

// --------------------------------------------------------------------------------
//  Block alignment and 128b/130b decoding
// --------------------------------------------------------------------------------
  logic [ALIGN_BUF_WD-1:0]   buf_align_rxdata;
  logic                      eios_found_gen6;
  logic                      err_skp_wo_skp_end;
  logic                      err_skp_after_sds;
  logic                      osfind_os_corrected, estore_os_corrected;
  logic                      eios_found_128b130b;
  logic                      eios_found_gen3_or_above;
  os_t [PHY_RXSB_WD-1:0]     decoded_os_found_128b130b;
  logic                      eieos_str_found_128b130b;
  logic                      err_syncheader_bypass;
  logic                      err_undef_syncheader;
  logic                      err_undef_skp;
  logic                      block_aligned;
  logic                      align_detected;
  logic [PHY_RAW_WD-1:0]     align_offset;
  assign buf_align_rxdata = buf_rxdata[RXDATA_BUF_WD-1-:ALIGN_BUF_WD];

  always_comb begin: eios_found_gen3_or_above_PROC
    eios_found_gen3_or_above = eios_found_128b130b;
    if(pipe_rate_sync2rx inside {`GEN6_RATE}) begin
      eios_found_gen3_or_above = eios_found_gen6;
    end
  end

  serdes_pipe_rx_blockalign
   #(
    .BUF_WD(ALIGN_BUF_WD)
  )  u_serdes_pipe_rx_blockalign (
    // ------------- input -----------------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .rx_sync_rst(muxed_rx_sync_rst),
    .sync_hdr_bypass_en(sync_hdr_bypass_en_sync2rx),
    .deskew_aligned_to_unaligned(deskew_aligned_to_unaligned_sync2rx),
    .flit_mode_enable(flit_mode_enable_sync2rx),
    .encdec_8b10b(encdec_8b10b_sync2rx),
    .raw_width(raw_width_sync2rx),
    .pipe_rate(pipe_rate_sync2rx),
    .pipe_rxdata(muxed_inv_rxdata_128b130b),
    .buf_rxdata(buf_align_rxdata),
    .pipe_blockaligncontrol(pipe_blockaligncontrol_sync2rx),
    .pipe_loopback_slave(pipe_loopback_slave_sync2rx),
    .eios_found(eios_found_gen3_or_above),
    .err_syncheader_bypass(err_syncheader_bypass),
    .err_undef_syncheader(err_undef_syncheader),
    .err_undef_skp(err_undef_skp),
    .err_skp_wo_skp_end(err_skp_wo_skp_end),
    .err_skp_after_sds(err_skp_after_sds),
    .err_estore_overflow(err_estore_overflow_sync2rx),
    .err_estore_underflow(err_estore_underflow_sync2rx),
    // ------------- output ----------------
    .eieos_str_found(eieos_str_found_128b130b),
    .block_aligned(block_aligned),
    .align_detected(align_detected),
    .align_offset(align_offset)
  );

// --------------------------------------------------------------------------------
//  128b/130b decoding
// --------------------------------------------------------------------------------
  logic [DECODE_BUF_WD-1:0]  buf_decode_rxdata;
  pipe_data128b_t            int_decoded_rxdata_128b130b;
  logic                      int_decoded_rxdatavalid;
  logic [PHY_RXSB_WD-1:0]    int_decoded_rxstartblock;
  pipe_syncheader_t          int_decoded_rxsyncheader;
  assign buf_decode_rxdata = buf_rxdata[RXDATA_BUF_WD-1-:DECODE_BUF_WD];

  serdes_pipe_rx_128b130b_decode
   #(
    .BUF_WD(DECODE_BUF_WD)
  )  u_serdes_pipe_rx_128b130b_decode (
    // ------------- input -----------------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .rx_sync_rst(rx_sync_rst),
    .sync_hdr_bypass_en(sync_hdr_bypass_en_sync2rx),
    .raw_width(raw_width_sync2rx),
    .symbol_width(symbol_width_sync2rx),
    .pipe_rate(pipe_rate_sync2rx),
    .pipe_rxdata(inv_regin_rxdata_128b130b),
    .buf_rxdata(buf_decode_rxdata),
    .block_aligned(block_aligned),
    .align_detected(align_detected),
    .align_offset(align_offset),
    // ------------- output ----------------
    .decoded_rxdata(int_decoded_rxdata_128b130b),
    .decoded_rxdatavalid(int_decoded_rxdatavalid),
    .decoded_rxstartblock(int_decoded_rxstartblock),
    .decoded_rxsyncheader(int_decoded_rxsyncheader)
  );

// --------------------------------------------------------------------------------
//  Syncheader generation
// --------------------------------------------------------------------------------
  logic [BYPASS_BUF_WD-1:0]  buf_bypass_rxdata;
  logic                      sdsos_found;
  logic                      skpos_found;
  logic                      eieos_found;
  logic                      sdsos_found_128b130b;
  logic                      skpos_found_128b130b;
  logic                      eieos_found_128b130b;
  logic                      eieos_found_for_deskew;
  pipe_data128b_t            bypassed_rxdata_128b130b;
  logic                      bypassed_rxdatavalid;
  logic [PHY_RXSB_WD-1:0]    bypassed_rxstartblock;
  pipe_syncheader_t          bypassed_rxsyncheader;
  logic                      sdsos_found_gen6;
  logic                      skpos_found_gen6;
  logic                      skp_end_found_gen6;
  logic                      eieos_found_gen6;
  logic [5:0]                sh_bypass_symbol_cnt;
  logic                      sh_bypass_symbol_cnt_adjust;
  logic                      in_datastream;
  assign buf_bypass_rxdata = buf_rxdata[RXDATA_BUF_WD-1-:BYPASS_BUF_WD];

  always_comb begin: sdsos_found_PROC
    // CXL defalut : 128b130b
    sdsos_found = sdsos_found_128b130b;
    skpos_found = skpos_found_128b130b;
    eieos_found = eieos_found_128b130b;
    if (encdec_1b1b_sync2rx) begin
      sdsos_found = sdsos_found_gen6;
      skpos_found = skpos_found_gen6;
      eieos_found = eieos_found_gen6;
    end
  end

  serdes_pipe_rx_synchdrgen
   #(
    .BUF_WD(BYPASS_BUF_WD)
  )  u_serdes_pipe_rx_synchdrgen (
    // ------------- input -----------------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .rx_sync_rst(raw_rx_sync_rst),
    .sync_hdr_bypass_en(sync_hdr_bypass_en_sync2rx),
    .flit_mode_enable(flit_mode_enable_sync2rx),
    .skpos_interval_block_num(skpos_interval_block_num_sync2rx),
    .loopback_state(loopback_state_sync2rx),
    .poll_compliance_state(poll_compliance_state_sync2rx),
    .pipe_srisen(pipe_srisen_sync2rx),
    .raw_width(raw_width_sync2rx),
    .symbol_width(symbol_width_sync2rx),
    .pipe_rate(pipe_rate_sync2rx),
    .pipe_rxvalid(muxed_rxvalid),
    .pipe_rxdata(muxed_inv_rxdata_128b130b),
    .buf_rxdata(buf_bypass_rxdata),
    .block_aligned(block_aligned),
    .align_detected(align_detected),
    .align_offset(align_offset),
    .sdsos_found(sdsos_found),
    .skpos_found(skpos_found),
    .eieos_found(eieos_found),
    .eieos_str_found(eieos_str_found_128b130b),
    .skpos_last_symbol(skpos_last_symbol),
    .eios_found(eios_found_gen3_or_above),
    // ------------- output ----------------
    .bypassed_rxdata(bypassed_rxdata_128b130b),
    .bypassed_rxdatavalid(bypassed_rxdatavalid),
    .bypassed_rxstartblock(bypassed_rxstartblock),
    .bypassed_rxsyncheader(bypassed_rxsyncheader),
    .symbol_cnt(sh_bypass_symbol_cnt),
    .symbol_cnt_adjust(sh_bypass_symbol_cnt_adjust),
    .in_datastream(in_datastream),
    .err_skp_after_sds(err_skp_after_sds),
    .err_syncheader_bypass(err_syncheader_bypass)
  );

  pipe_data128b_t          decoded_rxdata_128b130b;
  logic                    decoded_rxdatavalid;
  logic [PHY_RXSB_WD-1:0]  decoded_rxstartblock;
  pipe_syncheader_t        decoded_rxsyncheader;
  pipe_data128b_t          osfind_decoded_rxdata_128b130b;
  logic                    osfind_decoded_rxdatavalid;
  logic [PHY_RXSB_WD-1:0]  osfind_decoded_rxstartblock;
  pipe_syncheader_t        osfind_decoded_rxsyncheader;

  always_comb begin: decoded_rxdata_128b130b_PROC
    decoded_rxdata_128b130b = int_decoded_rxdata_128b130b;
    decoded_rxdatavalid = int_decoded_rxdatavalid;
    decoded_rxstartblock = int_decoded_rxstartblock;
    decoded_rxsyncheader = int_decoded_rxsyncheader;
    if(low_latency_ctrl_en_sync2rx) begin
      decoded_rxdata_128b130b = bypassed_rxdata_128b130b;
      decoded_rxdatavalid = bypassed_rxdatavalid;
      decoded_rxstartblock = bypassed_rxstartblock;
      decoded_rxsyncheader = bypassed_rxsyncheader;
    end
  end

  always_comb begin: osfind_decoded_rxdata_128b130b_PROC
    // CXL defalut : 128b130b
    osfind_decoded_rxdata_128b130b = decoded_rxdata_128b130b;
    osfind_decoded_rxdatavalid     = decoded_rxdatavalid;
    osfind_decoded_rxstartblock    = decoded_rxstartblock;
    osfind_decoded_rxsyncheader    = decoded_rxsyncheader;
    if (encdec_1b1b_sync2rx) begin
      osfind_decoded_rxdata_128b130b = int_decoded_rxdata_128b130b;
      osfind_decoded_rxdatavalid     = int_decoded_rxdatavalid;
      osfind_decoded_rxstartblock    = int_decoded_rxstartblock;
      osfind_decoded_rxsyncheader    = int_decoded_rxsyncheader;
    end
  end

  serdes_pipe_rx_128b130b_osfind
    u_serdes_pipe_rx_128b130b_osfind (
    // ------------- input -----------------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .rx_sync_rst(muxed_rx_sync_rst),
    .symbol_width(symbol_width_sync2rx),
    .pipe_rate(pipe_rate_sync2rx),
    .sync_hdr_bypass_en(sync_hdr_bypass_en_sync2rx),
    .flit_mode_enable(flit_mode_enable_sync2rx),
    .block_aligned(block_aligned),
    .decoded_rxdata(osfind_decoded_rxdata_128b130b),
    .decoded_rxdatavalid(osfind_decoded_rxdatavalid),
    .decoded_rxstartblock(osfind_decoded_rxstartblock),
    .decoded_rxsyncheader(osfind_decoded_rxsyncheader),
    // ------------- output ----------------
    .sdsos_found(sdsos_found_128b130b),
    .skpos_found(skpos_found_128b130b),
    .eieos_found(eieos_found_128b130b),
    .eieos_found_for_deskew(eieos_found_for_deskew),
    .eios_found(eios_found_128b130b),
    .os_found(decoded_os_found_128b130b),
    .err_undef_syncheader(err_undef_syncheader),
    .err_undef_skp(err_undef_skp)
  );

  serdes_pipe_rx_1b1b_osfind
    u_serdes_pipe_rx_1b1b_osfind (
    // ------------- input -----------------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .rx_sync_rst(muxed_rx_sync_rst),
    .symbol_width(symbol_width_sync2rx),
    .pipe_rate(pipe_rate_sync2rx),
    .flit_mode_enable(flit_mode_enable_sync2rx),
    .block_aligned(block_aligned),
    .symbol_cnt(sh_bypass_symbol_cnt),
    .symbol_cnt_adjust(sh_bypass_symbol_cnt_adjust),
    .in_datastream(in_datastream),
    .poll_compliance_state(poll_compliance_state_sync2rx),
    .decoded_rxdata(bypassed_rxdata_128b130b),
    .decoded_rxdatavalid(bypassed_rxdatavalid),
    .decoded_rxstartblock(bypassed_rxstartblock),
    .decoded_rxsyncheader(bypassed_rxsyncheader),
    // ------------- output ----------------
    .sdsos_found(sdsos_found_gen6),
    .skpos_found(skpos_found_gen6),
    .eieos_found(eieos_found_gen6),
    .skpos_last_symbol(skpos_last_symbol),
    .skp_end_found_gen6(skp_end_found_gen6),
    .eios_found(eios_found_gen6),
    .err_skp_wo_skp_end(err_skp_wo_skp_end)
    ,
    .os_corrected(osfind_os_corrected)
  );

  pipe_data128b_t          estore_in_rxdata;
  logic                    estore_in_rxdatavalid;
  logic [PHY_RXSB_WD-1:0]  estore_in_rxstartblock;
  pipe_syncheader_t        estore_in_rxsyncheader;
  logic                    estore_in_block_aligned;
  os_t [PHY_RXSB_WD-1:0]   estore_in_os_found;
  logic                    estore_in_os_corrected;

  pipe_data128b_t            os_cor_rxdata;
  logic                      os_cor_rxdatavalid;
  logic [PHY_RXSB_WD-1:0]    os_cor_rxstartblock;
  pipe_syncheader_t          os_cor_rxsyncheader;
  logic                      os_cor_block_aligned;
  logic                      os_cor_os_corrected;
  os_t [OS_FIND_GEN6_WD-1:0] decoded_os_found, os_cor_os_found;

// --------------------------------------------------------------------------------
//  OS correction for 1b1b 
// --------------------------------------------------------------------------------
  always_comb begin: decoded_os_found_PROC
    for(int i = 0; i < OS_FIND_GEN6_WD; i++) begin
      casez({skpos_found_gen6,skp_end_found_gen6,sdsos_found_gen6,eios_found_gen6,eieos_found_gen6})
        5'b10???: decoded_os_found[i] = SKP;
        5'b11???: decoded_os_found[i] = SKP_END;
        5'b0?1??: decoded_os_found[i] = SDS;
        5'b0?010: decoded_os_found[i] = EIOS;
        5'b0?001: decoded_os_found[i] = EIEOS;
         default: decoded_os_found[i] = NONE;
      endcase
    end
  end


  always_comb begin: estore_in_PROC
    estore_in_rxdata = decoded_rxdata_128b130b;
    estore_in_rxdatavalid = decoded_rxdatavalid;
    estore_in_rxstartblock = decoded_rxstartblock;
    estore_in_rxsyncheader = decoded_rxsyncheader;
    estore_in_block_aligned = block_aligned;
  end  

  always_comb begin: estore_in_os_found_PROC
    estore_in_os_found = decoded_os_found_128b130b;
    estore_in_os_corrected = '0;
    if(encdec_1b1b_sync2rx) begin
       estore_in_os_corrected = osfind_os_corrected;
      // Convert os_found from per PHY_NB/8 to PHY_RXSB_WD
      for(int i = 0; i < PHY_RXSB_WD; i++) begin
        estore_in_os_found[i] = decoded_os_found[i/2];
      end
    end
  end  

// --------------------------------------------------------------------------------
//  Elastic buffer
// --------------------------------------------------------------------------------
  logic                    estore_rdvalid;
  pipe_data_t              estore_rddata;
  pipe_data10b_t           estore_rddata_8b10b;
  logic                    estore_rddatavalid;
  logic                    estore_mode;
  logic [PHY_RXSB_WD-1:0]  estore_rxstartblock;
  pipe_syncheader_t        estore_rxsyncheader;
  logic                    err_estore_128b130b_decode;
  os_t [PHY_RXSB_WD-1:0]   estore_os_found_enc;
  os_t [PHY_RXSB_WD-1:0]   os_found_enc;
  os_found_t               os_found;
  logic                    sts_estore_skp_add;
  logic                    sts_estore_skp_rem;
  logic                    err_estore_overflow;
  logic                    err_estore_underflow;
  assign estore_rddata_8b10b = pipe_data10b_t'(estore_rddata);

  serdes_pipe_rx_estore
    u_serdes_pipe_rx_estore (
    // ---------- input (clk) --------------
    .clk(clk),
    .rst_n(rst_n),
    .estore_sync_rst(buf_sync_rst),
    .sync_hdr_bypass_en(sync_hdr_bypass_en),
    .encdec_8b10b(encdec_8b10b),
    .symbol_width(symbol_width),
    .raw_width(raw_width),
    .pipe_rate(pipe_rate),
    .pipe_width(pipe_width),
    .pipe_srisen(pipe_srisen),
    .pipe_loopback_slave(orig_pipe_loopback_slave),
    .pipe_elasticbuffermode(orig_pipe_elasticbuffermode),
    // ---------- input (rx_clk) -----------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .estore_rx_sync_rst(raw_rx_sync_rst),
    .drift_buffer_en(drift_buffer_en_sync2rx),
    .encdec_8b10b_sync2rx(encdec_8b10b_sync2rx),
    .symbol_width_sync2rx(symbol_width_sync2rx),
    .pipe_rate_sync2rx(pipe_rate_sync2rx),
    .pipe_width_sync2rx(pipe_width_sync2rx),
    .pipe_rxvalid(muxed_rxvalid),
    .symbol_locked(symbol_locked),
    .locked_rxdata(locked_rxdata),
    .block_aligned(estore_in_block_aligned),
    .decoded_rxdata(estore_in_rxdata),
    .decoded_rxdatavalid(estore_in_rxdatavalid),
    .decoded_rxstartblock(estore_in_rxstartblock),
    .decoded_rxsyncheader(estore_in_rxsyncheader),
    .decoded_os_found(estore_in_os_found),
    .err_undef_skp(err_undef_skp),
    .osfind_os_corrected(estore_in_os_corrected),
    // ---------- output (clk) -------------
    .estore_rdvalid(estore_rdvalid),
    .estore_rddata(estore_rddata),
    .estore_rddatavalid(estore_rddatavalid),
    .estore_mode(estore_mode),
    .estore_rxstartblock(estore_rxstartblock),
    .estore_rxsyncheader(estore_rxsyncheader),
    .estore_os_found(estore_os_found_enc),
    .err_128b130b_decode(err_estore_128b130b_decode),
    .estore_os_corrected(estore_os_corrected),
    .sts_estore_skp_add(sts_estore_skp_add),
    .sts_estore_skp_rem(sts_estore_skp_rem),
    .err_estore_overflow(err_estore_overflow),
    .err_estore_underflow(err_estore_underflow)
  );


// --------------------------------------------------------------------------------
//  Drift buffer
// --------------------------------------------------------------------------------
  logic                    dbuf_rdvalid;
  pipe_data128b_t          dbuf_rddata;
  logic                    dbuf_rddatavalid;
  logic [PHY_RXSB_WD-1:0]  dbuf_rxstartblock;
  pipe_syncheader_t        dbuf_rxsyncheader;
  os_t  [PHY_RXSB_WD-1:0]  dbuf_os_found_enc;
  logic                    err_dbuf_128b130b_decode;

  serdes_pipe_rx_driftbuffer
    u_serdes_pipe_rx_driftbuffer (
    // ---------- input (clk) --------------
    .clk(clk),
    .rst_n(rst_n),
    .dbuf_sync_rst(buf_sync_rst),
    .sync_hdr_bypass_en(sync_hdr_bypass_en),
    .low_ptr_en(drift_buffer_low_ptr_en),
    .rcvry_lock_state(rcvry_lock_state),
    .deskew_en(deskew_en),
    .deskew_complete(deskew_complete),
    .deskew_redo(deskew_redo),
    .symbol_width(symbol_width),
    .raw_width(raw_width),
    .encdec_128b130b(encdec_128b130b),
    .encdec_1b1b(encdec_1b1b),
    // ---------- input (rx_clk) -----------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .dbuf_rx_sync_rst(raw_rx_sync_rst),
    .drift_buffer_en(drift_buffer_en_sync2rx),
    .pipe_rxvalid(muxed_rxvalid),
    .block_aligned(estore_in_block_aligned),
    .decoded_rxdata(estore_in_rxdata),
    .decoded_rxdatavalid(estore_in_rxdatavalid),
    .decoded_rxstartblock(estore_in_rxstartblock),
    .decoded_rxsyncheader(estore_in_rxsyncheader),
    .decoded_os_found(estore_in_os_found),
    .eieos_found(eieos_found_for_deskew),
    .err_undef_skp(err_undef_skp),
    .encdec_1b1b_sync2rx(encdec_1b1b_sync2rx),
    // ---------- output (clk) -------------
    .dbuf_rdvalid(dbuf_rdvalid),
    .dbuf_rddata(dbuf_rddata),
    .dbuf_rddatavalid(dbuf_rddatavalid),
    .dbuf_rxstartblock(dbuf_rxstartblock),
    .dbuf_rxsyncheader(dbuf_rxsyncheader),
    .dbuf_os_found(dbuf_os_found_enc),
    .err_128b130b_decode(err_dbuf_128b130b_decode),
    .deskew_aligned_to_unaligned(deskew_aligned_to_unaligned),
    .deskew_aligned(deskew_aligned),
    .deskew_ptr(deskew_ptr),
    .deskew_avail(deskew_avail),
    .deskew_req(deskew_req)
  );

  always_comb begin: os_found_enc_PROC
    os_found_enc = estore_os_found_enc;
    if(drift_buffer_en) begin
       os_found_enc = dbuf_os_found_enc;
    end
  end

  always_comb begin: os_found_PROC
    for(int i = 0; i < PHY_RXSB_WD; i++) begin
      os_found[i][0] = (os_found_enc[i] inside {SKP,SKP_END});
      os_found[i][1] = (os_found_enc[i] inside {SKP_END});
      os_found[i][2] = (os_found_enc[i] inside {EIOS});
      os_found[i][3] = (os_found_enc[i] inside {EIEOS});
      os_found[i][4] = (os_found_enc[i] inside {SDS});
    end
  end

// --------------------------------------------------------------------------------
//  Synchronizer
// --------------------------------------------------------------------------------
  serdes_pipe_rx_clksync
    u_serdes_pipe_rx_clksync (
    // ---------- input (clk) --------------
    .clk(clk),
    .rst_n(rst_n),
    .sync_hdr_bypass_en(sync_hdr_bypass_en),
    .drift_buffer_en(drift_buffer_en),
    .deskew_aligned_to_unaligned(deskew_aligned_to_unaligned),
    .skpos_interval_block_num(skpos_interval_block_num),
    .loopback_state(loopback_state),
    .poll_compliance_state(poll_compliance_state),
    .pipe_srisen(pipe_srisen),
    .flit_mode_enable(flit_mode_enable),
    .pipe_rate(pipe_rate),
    .pipe_width(pipe_width),
    .pipe_loopback_slave(orig_pipe_loopback_slave),
    .pipe_rxpolarity(orig_pipe_rxpolarity),
    .pipe_blockaligncontrol(orig_pipe_blockaligncontrol),
    .err_estore_overflow(err_estore_overflow),
    .err_estore_underflow(err_estore_underflow),
    // ---------- input (rx_clk) -----------
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    // ---------- output (clk) -------------
    .buf_sync_rst(buf_sync_rst),
    // ---------- output (rx_clk) ----------
    .sync_hdr_bypass_en_sync2rx(sync_hdr_bypass_en_sync2rx),
    .drift_buffer_en_sync2rx(drift_buffer_en_sync2rx),
    .deskew_aligned_to_unaligned_sync2rx(deskew_aligned_to_unaligned_sync2rx),
    .skpos_interval_block_num_sync2rx(skpos_interval_block_num_sync2rx),
    .loopback_state_sync2rx(loopback_state_sync2rx),
    .poll_compliance_state_sync2rx(poll_compliance_state_sync2rx),
    .pipe_srisen_sync2rx(pipe_srisen_sync2rx),
    .flit_mode_enable_sync2rx(flit_mode_enable_sync2rx),
    .pipe_rate_sync2rx(pipe_rate_sync2rx),
    .pipe_width_sync2rx(pipe_width_sync2rx),
    .pipe_loopback_slave_sync2rx(pipe_loopback_slave_sync2rx),
    .pipe_rxpolarity_sync2rx(pipe_rxpolarity_sync2rx),
    .pipe_blockaligncontrol_sync2rx(pipe_blockaligncontrol_sync2rx),
    .rx_sync_rst(raw_rx_sync_rst),
    .err_estore_overflow_sync2rx(err_estore_overflow_sync2rx),
    .err_estore_underflow_sync2rx(err_estore_underflow_sync2rx)
  );

// --------------------------------------------------------------------------------
//  8b/10b decoding
// --------------------------------------------------------------------------------
  pipe_data8b_t             decoded_rxdata_8b10b;
  logic [PHY_8B10B_NB-1:0]  decoded_rxdatak;
  logic                     err_8b10b_decode;
  logic                     err_8b10b_disp;

  serdes_pipe_rx_8b10b_decode
    u_serdes_pipe_rx_8b10b_decode (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .encdec_8b10b(encdec_8b10b),
    .symbol_width(symbol_width_8b10b),
    .estore_rdvalid(estore_rdvalid),
    .estore_rddata(estore_rddata_8b10b),
    .estore_rddatavalid(estore_rddatavalid),
    .err_estore_overflow(err_estore_overflow),
    .err_estore_underflow(err_estore_underflow),
    // ------------- output ----------------
    .decoded_rxdata(decoded_rxdata_8b10b),
    .decoded_rxdatak(decoded_rxdatak),
    .err_code(err_8b10b_decode),
    .err_disp(err_8b10b_disp)
  );

// --------------------------------------------------------------------------------
//  RxStatus generation
// --------------------------------------------------------------------------------
  rxstatus_t  estore_rxstatus, pre_estore_rxstatus;
  rxstatus_t  dbuf_rxstatus;

  always_comb begin: orig_pipe_rxstatus_PROC
    // RxStatus is driven to receiver not present ('b000) or receiver present ('b011) while receiver detection.
    // Note the dependency between PhyStatus and RxStatus.
    if(serdes_pipe_txdetectrx) begin
      orig_pipe_rxstatus = (serdes_pipe_rxstatus == RXSTAT_RX_DET) ? RXSTAT_RX_DET : RXSTAT_DATA_OK;
    end
    else begin
      orig_pipe_rxstatus = estore_rxstatus;
      if(drift_buffer_en) begin
        orig_pipe_rxstatus = dbuf_rxstatus;
      end
    end
  end

  always_comb begin: pre_estore_rxstatus_PROC
    pre_estore_rxstatus = RXSTAT_DATA_OK;
    if(estore_rdvalid) begin
      if(encdec_8b10b) begin
        pre_estore_rxstatus = (err_8b10b_decode)     ? RXSTAT_DEC_ERR :
                              (err_estore_overflow)  ? RXSTAT_EBUF_OFLOW :
                              (err_estore_underflow) ? RXSTAT_EBUF_UFLOW :
                              (err_8b10b_disp)       ? RXSTAT_DISP_ERR :
                              (sts_estore_skp_add)   ? RXSTAT_SKP_ADD :
                              (sts_estore_skp_rem)   ? RXSTAT_SKP_REM :
                                                       RXSTAT_DATA_OK;
      end
      else begin
        pre_estore_rxstatus = (err_estore_128b130b_decode) ? RXSTAT_DEC_ERR :
                              (err_estore_overflow)        ? RXSTAT_EBUF_OFLOW :
                              (err_estore_underflow)       ? RXSTAT_EBUF_UFLOW :
                              (sts_estore_skp_add)         ? RXSTAT_SKP_ADD :
                              (sts_estore_skp_rem)         ? RXSTAT_SKP_REM :
                                                             RXSTAT_DATA_OK;
      end
    end
  end

  always_comb begin: dbuf_rxstatus_PROC
    dbuf_rxstatus = RXSTAT_DATA_OK;
    if(dbuf_rdvalid) begin
      if(err_dbuf_128b130b_decode) begin
        dbuf_rxstatus = RXSTAT_DEC_ERR;
      end
    end
  end

// --------------------------------------------------------------------------------
//  Original PIPE registered output
// --------------------------------------------------------------------------------

// spyglass disable_block W497
// SMD: Not all bits of a bus are set.
// SJ:  All bits are properly set.
  struct packed {
    logic [ORIG_DATA_WD-1:0]  rxdata;
    logic [PHY_NB-1:0]        rxdatak;
    logic                     rxvalid;
    logic                     rxdatavalid;
    logic [PHY_RXSB_WD-1:0]   rxstartblock;
    logic [PHY_RXSH_WD-1:0]   rxsyncheader;
    os_found_t                os_found;
    rxstatus_t                rxstatus;
    logic                     os_corrected;
    }  pre_orig_pipe_sdata, orig_pipe_sdata;
// spyglass enable_block W497

  always_comb begin: pre_orig_pipe_sdata_PROC
    pre_orig_pipe_sdata = '0;
    pre_orig_pipe_sdata.rxvalid = estore_rdvalid;
    pre_orig_pipe_sdata.rxdatavalid = estore_rddatavalid;
    pre_orig_pipe_sdata.rxstatus = pre_estore_rxstatus;
    pre_orig_pipe_sdata.os_corrected = estore_os_corrected;
    if(encdec_8b10b) begin
      pre_orig_pipe_sdata.rxdata = $bits(pre_orig_pipe_sdata.rxdata)'(decoded_rxdata_8b10b);
      pre_orig_pipe_sdata.rxdatak = $bits(pre_orig_pipe_sdata.rxdatak)'(decoded_rxdatak);
    end
    else begin
      for(int i = 0; i < PHY_NB; i++) begin
        pre_orig_pipe_sdata.rxdata[SYM_WD*i+:SYM_WD] = estore_rddata[i][SYM_WD-1:0];
      end
      pre_orig_pipe_sdata.rxstartblock = estore_rxstartblock;
      pre_orig_pipe_sdata.rxsyncheader = estore_rxsyncheader;
      pre_orig_pipe_sdata.os_found = os_found;
    end
  end

  always_comb begin: orig_pipe_rxdata_PROC
    orig_pipe_rxdata = orig_pipe_sdata.rxdata;
    orig_pipe_rxdatak = orig_pipe_sdata.rxdatak;
    orig_pipe_rxvalid = orig_pipe_sdata.rxvalid;
    orig_pipe_rxdatavalid = orig_pipe_sdata.rxdatavalid;
    orig_pipe_rxstartblock = orig_pipe_sdata.rxstartblock;
    orig_pipe_rxsyncheader = orig_pipe_sdata.rxsyncheader;
    orig_pipe_os_found = orig_pipe_sdata.os_found;
    estore_rxstatus = orig_pipe_sdata.rxstatus;
    os_corrected = orig_pipe_sdata.os_corrected;
    if(drift_buffer_en) begin
      orig_pipe_rxdata = dbuf_rddata;
      orig_pipe_rxvalid = dbuf_rdvalid;
      orig_pipe_rxdatavalid = dbuf_rddatavalid;
      orig_pipe_rxstartblock = dbuf_rxstartblock;
      orig_pipe_rxsyncheader = dbuf_rxsyncheader;
      orig_pipe_os_found = os_found;
    end
  end

  delay_n
   #(
    .N(1),
    .WD($bits(pre_orig_pipe_sdata)),
    .RESETVAL('0)
  ) u_delay_n_orig_pipe (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .clear(1'h0),
    .din(pre_orig_pipe_sdata),
    // ------------- output ----------------
    .dout(orig_pipe_sdata)
  );

  logic regout_serdes_pipe_rxready;

  delay_n
   #(
    .N(1),
    .WD($bits(regout_serdes_pipe_rxready)),
    .RESETVAL('0)
  ) u_delay_n_serdes_pipe_rxready (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .clear(1'h0),
    .din(dbuf_rdvalid),
    // ------------- output ----------------
    .dout(regout_serdes_pipe_rxready)
  );

  always_comb begin: serdes_pipe_rxready_PROC
    serdes_pipe_rxready = orig_pipe_rxvalid;
    if(drift_buffer_en) begin
      serdes_pipe_rxready = regout_serdes_pipe_rxready;
    end
  end

// --------------------------------------------------------------------------------
//  osfound end for EI/EIE/SDS
// --------------------------------------------------------------------------------
  logic [3:0]                    osfound_cnt_incr;
  logic [4:0]                    osfound_cnt;      // count 0-16
  logic [3:0]                    pre_osfound_cnt;  // count 0-15
  // Current RTL supports the pipe_width up to 8s. This symbol couner control is necessary up to 8s.
  // For 16s or above, new approach needs to be considered.
  always_comb begin : osfound_cnt_incr_PROC
    case (pipe_width)
      0 : osfound_cnt_incr = 4'd1; // PIPE 8-bit(1s)
      1 : osfound_cnt_incr = 4'd2; // PIPE 16-bit(2s)
      2 : osfound_cnt_incr = 4'd4; // PIPE 32-bit(4s)
      3 : osfound_cnt_incr = 4'd8; // PIPE 64-bit(8s)
      default : osfound_cnt_incr = 4'd1;
    endcase
  end

  // Symbol counter to find end of Ordered-Set
  always_comb begin : osfound_cnt_PROC
    logic [PHY_RXSB_WD*5-1:0] tmp_os_found;
    tmp_os_found = orig_pipe_os_found;

    osfound_cnt = $bits(osfound_cnt)'(pre_osfound_cnt);
    if (orig_pipe_rxdatavalid) begin
      if (|tmp_os_found) begin
        if (orig_pipe_rxstartblock[0]) begin
          osfound_cnt = $bits(osfound_cnt)'(osfound_cnt_incr);
        end
        else if (|pre_osfound_cnt) begin
          osfound_cnt = $bits(osfound_cnt)'(pre_osfound_cnt + osfound_cnt_incr);
        end
      end
      else begin
        osfound_cnt = '0;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin: pre_osfound_cnt_PROC
    if(!rst_n) begin
      pre_osfound_cnt <= #`TP '0;
    end
    else begin
      pre_osfound_cnt <= #`TP osfound_cnt[3:0]; // osfound_cnt=16->pre_osfound_cnt=0
    end
  end

  always_comb begin : orig_pipe_os_found_end_PROC
    // Gen3/4/5
    orig_pipe_os_found_end = '0;
      orig_pipe_os_found_end[0] = ((osfound_cnt==5'd16) && (orig_pipe_os_found[0][OS_FOUND_EIOS] || orig_pipe_os_found[0][OS_FOUND_EIEOS] || orig_pipe_os_found[0][OS_FOUND_SDS]));  // EIOS end at Symbol-16

    // Gen6+
    if (encdec_1b1b) begin           // This condtion is alined with sdsos_found/skpos_found/eieos_found (encdec_1b1b_sync2rx)
      orig_pipe_os_found_end = '1; // orig_pipe_os_found_end is always 1
    end
  end
// --------------------------------------------------------------------------------
//  Loopback output
// --------------------------------------------------------------------------------
  logic [SERDES_DATA_WD-1:0] pre_loopback_rxdata;
  logic                      pre_loopback_rxdatavalid;
  logic [PHY_RXSB_WD-1:0]    pre_loopback_rxstartblock;
  logic [PHY_RXSH_WD-1:0]    pre_loopback_rxsyncheader;

  // Loopback is only capable if elastic buffer is running with nominal half-full mode.
  always_comb begin: pre_loopback_rxdatavalid_PROC
    pre_loopback_rxdatavalid = estore_rddatavalid;
    if(estore_mode) begin
      pre_loopback_rxdatavalid = 1'h0;
    end
  end

  always_comb begin: pre_loopback_rxdata_PROC
    pre_loopback_rxdata = '0;
    pre_loopback_rxstartblock = '0;
    pre_loopback_rxsyncheader = '0;
    if(pre_loopback_rxdatavalid) begin
      if(encdec_8b10b) begin
        for(int i = 0; i < PHY_8B10B_NB; i++) begin
          pre_loopback_rxdata[SYM_10B_WD*i+:SYM_10B_WD] = {<< {estore_rddata_8b10b[i]}};
        end
      end
      else begin
        pre_loopback_rxdata = estore_rddata;
        pre_loopback_rxstartblock = estore_rxstartblock;
        pre_loopback_rxsyncheader = estore_rxsyncheader;
      end
    end
  end

  delay_n
   #(
    .N(0),
    .WD($bits({pre_loopback_rxdata,pre_loopback_rxdatavalid,pre_loopback_rxstartblock,pre_loopback_rxsyncheader})),
    .RESETVAL('0)
  ) u_delay_n_loopback_data (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .clear(1'h0),
    .din({pre_loopback_rxdata,pre_loopback_rxdatavalid,pre_loopback_rxstartblock,pre_loopback_rxsyncheader}),
    // ------------- output ----------------
    .dout({loopback_rxdata,loopback_rxdatavalid,loopback_rxstartblock,loopback_rxsyncheader})
  );


endmodule: serdes_pipe_rx
