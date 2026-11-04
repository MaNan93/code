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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_lane.sv#12 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture per lane top module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_lane

  import serdes_pipe_pkg::*;
(
  // ------------- input -----------------
  input logic                        clk,
  input logic                        rst_n,
  input logic                        sync_hdr_bypass_en,
  input logic                        rcvry_lock_state,
  input logic                        drift_buffer_en,
  input logic                        drift_buffer_low_ptr_en,
  input logic                        deskew_en,
  input logic                        deskew_complete,
  input logic                        deskew_redo,
  input logic [9:0]                  skpos_interval_block_num,
  input logic                        poll_compliance_state,
  input logic                        rx_clk,
  input logic                        rx_rst_n,
  input logic                        encdec_8b10b,
  input logic                        loopback_state,
  input logic [RATE_WD-1:0]          pipe_rate,
  input logic [WIDTH_WD-1:0]         pipe_width,
  input logic                        pipe_srisen,
  input logic                        flit_mode_enable,
  input logic [SERDES_DATA_WD-1:0]   serdes_pipe_rxdata,
  input logic                        serdes_pipe_rxvalid,
  input logic [2:0]                  serdes_pipe_rxstatus,
  input logic [ORIG_DATA_WD-1:0]     orig_pipe_txdata,
  input logic [PHY_NB-1:0]           orig_pipe_txdatak,
  input logic                        orig_pipe_txelecidle,
  input logic                        orig_pipe_txcompliance,
  input logic                        orig_pipe_txdetectrx_loopback,
  input logic                        orig_pipe_txdatavalid,
  input logic                        orig_pipe_txstartblock,
  input logic [1:0]                  orig_pipe_txsyncheader,
  input logic                        orig_pipe_blockaligncontrol,
  input logic                        orig_pipe_rxpolarity,
  input logic                        orig_pipe_elasticbuffermode,
  // ------------- output ----------------
  output logic [7:0]                 deskew_ptr,
  output logic                       deskew_avail,
  output logic                       deskew_aligned,
  output logic                       deskew_req,
  output logic                       os_corrected,
  output logic [ORIG_DATA_WD-1:0]    orig_pipe_rxdata,
  output logic [PHY_NB-1:0]          orig_pipe_rxdatak,
  output logic                       orig_pipe_rxvalid,
  output logic                       orig_pipe_rxdatavalid,
  output logic [2:0]                 orig_pipe_rxstatus,
  output logic                       serdes_pipe_txdatavalid,
  output logic [PHY_RXSB_WD-1:0]     orig_pipe_rxstartblock,
  output logic [PHY_RXSH_WD-1:0]     orig_pipe_rxsyncheader,
  output os_found_t                  orig_pipe_os_found,
  output logic [PHY_RXSB_WD-1:0]     orig_pipe_os_found_end,
  output logic [SERDES_DATA_WD-1:0]  serdes_pipe_txdata,
  output logic [PHY_TXEI_WD-1:0]     serdes_pipe_txelecidle,
  output logic                       serdes_pipe_txdetectrx,
  output logic                       serdes_pipe_rxready
);

// --------------------------------------------------------------------------------
//  Registered input signals (for zero reset signals)
// --------------------------------------------------------------------------------

    logic                sync_hdr_bypass_en_d;
    logic                rcvry_lock_state_d;
    logic                drift_buffer_en_d;
    logic                drift_buffer_low_ptr_en_d;
    logic                deskew_en_d;
    logic                deskew_redo_d;
    logic                loopback_state_d;
    logic [RATE_WD-1:0]  pipe_rate_d;
    logic                pipe_srisen_d;
    logic                poll_compliance_state_d; 



  struct packed {
    logic                sync_hdr_bypass_en;
    logic                rcvry_lock_state; // from ltssm_state
    logic                drift_buffer_en;
    logic                drift_buffer_low_ptr_en;
    logic                deskew_en;
    logic                deskew_redo;
    logic                loopback_state; // from ltssm_state
    logic [RATE_WD-1:0]  pipe_rate;
    logic                pipe_srisen;
    logic                poll_compliance_state; 
    }  pre_serdes_regin_sdata, serdes_regin_sdata;

  always_comb begin: pre_serdes_regin_sdata_PROC
    pre_serdes_regin_sdata.sync_hdr_bypass_en = sync_hdr_bypass_en;
    pre_serdes_regin_sdata.rcvry_lock_state = rcvry_lock_state;
    pre_serdes_regin_sdata.drift_buffer_en = drift_buffer_en;
    pre_serdes_regin_sdata.drift_buffer_low_ptr_en = drift_buffer_low_ptr_en;
    pre_serdes_regin_sdata.deskew_en = deskew_en;
    pre_serdes_regin_sdata.deskew_redo = deskew_redo;
    pre_serdes_regin_sdata.loopback_state = loopback_state;
    pre_serdes_regin_sdata.pipe_rate = pipe_rate;
    pre_serdes_regin_sdata.pipe_srisen = pipe_srisen;
    pre_serdes_regin_sdata.poll_compliance_state = poll_compliance_state;
  end

  always_comb begin: serdes_regin_sdata_PROC
    sync_hdr_bypass_en_d = serdes_regin_sdata.sync_hdr_bypass_en;
    rcvry_lock_state_d = serdes_regin_sdata.rcvry_lock_state;
    drift_buffer_en_d = serdes_regin_sdata.drift_buffer_en;
    drift_buffer_low_ptr_en_d = serdes_regin_sdata.drift_buffer_low_ptr_en;
    deskew_en_d = serdes_regin_sdata.deskew_en;
    deskew_redo_d = serdes_regin_sdata.deskew_redo;
    loopback_state_d = serdes_regin_sdata.loopback_state;
    pipe_rate_d = serdes_regin_sdata.pipe_rate;
    pipe_srisen_d = serdes_regin_sdata.pipe_srisen;
    poll_compliance_state_d = serdes_regin_sdata.poll_compliance_state;
  end

  delay_n
   #(
    .N(1),
    .WD($bits(pre_serdes_regin_sdata)),
    .RESETVAL('0)
  ) u_delay_n_regin (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .clear(1'h0),
    .din(pre_serdes_regin_sdata),
    // ------------- output ----------------
    .dout(serdes_regin_sdata)
  );

// --------------------------------------------------------------------------------
//  Registered input signals (for non-zero reset signals)
// --------------------------------------------------------------------------------
  logic                encdec_8b10b_d;

  struct packed {
    logic                encdec_8b10b;
    }  pre_serdes_regin_sdata_non_zero_rst, serdes_regin_sdata_non_zero_rst;

  always_comb begin: pre_serdes_regin_sdata_non_zero_rst_PROC
    pre_serdes_regin_sdata_non_zero_rst.encdec_8b10b = encdec_8b10b;
  end

  always_comb begin: serdes_regin_sdata_non_zero_rst_PROC
    encdec_8b10b_d = serdes_regin_sdata_non_zero_rst.encdec_8b10b;
  end

  delay_n
   #(
    .N(1),
    .WD($bits(pre_serdes_regin_sdata_non_zero_rst)),
    .RESETVAL('1)
  ) u_delay_n_regin_non_zero_rst (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .clear(1'h0),
    .din(pre_serdes_regin_sdata_non_zero_rst),
    // ------------- output ----------------
    .dout(serdes_regin_sdata_non_zero_rst)
  );

// --------------------------------------------------------------------------------
//  Registered input signals (for pipe_width)
// --------------------------------------------------------------------------------
  localparam int WIDTH_RST_VAL = (`CX_PHY_NB_GEN1 == 4) ? 2:
                                 (`CX_PHY_NB_GEN1 == 2) ? 1:
                                                          0;
  logic [WIDTH_WD-1:0] pipe_width_d;

  delay_n
   #(
    .N(1),
    .WD($bits(pipe_width)),
    .RESETVAL(WIDTH_RST_VAL)
  ) u_delay_n_regin_pipe_width (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .clear(1'h0),
    .din(pipe_width),
    // ------------- output ----------------
    .dout(pipe_width_d)
  );

  logic  orig_pipe_txdetectrx;
  logic  orig_pipe_loopback_slave;
  assign orig_pipe_txdetectrx     = (loopback_state_d) ? 1'h0 : orig_pipe_txdetectrx_loopback;
  assign orig_pipe_loopback_slave = (loopback_state_d) ? orig_pipe_txdetectrx_loopback : 1'h0;

  logic [SERDES_DATA_WD-1:0]  loopback_rxdata;
  logic                       loopback_rxdatavalid;
  logic [PHY_RXSB_WD-1:0]     loopback_rxstartblock;
  logic [PHY_RXSH_WD-1:0]     loopback_rxsyncheader;

  serdes_pipe_tx
    u_serdes_pipe_tx (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .sync_hdr_bypass_en(sync_hdr_bypass_en_d),
    .encdec_8b10b(encdec_8b10b_d),
    .pipe_rate(pipe_rate_d),
    .pipe_width(pipe_width_d),
    .orig_pipe_txdata(orig_pipe_txdata),
    .orig_pipe_txdatak(orig_pipe_txdatak),
    .orig_pipe_txelecidle(orig_pipe_txelecidle),
    .orig_pipe_txcompliance(orig_pipe_txcompliance),
    .orig_pipe_txdetectrx(orig_pipe_txdetectrx),
    .orig_pipe_loopback_slave(orig_pipe_loopback_slave),
    .orig_pipe_txdatavalid(orig_pipe_txdatavalid),
    .orig_pipe_txstartblock(orig_pipe_txstartblock),
    .orig_pipe_txsyncheader(orig_pipe_txsyncheader),
    .loopback_rxdata(loopback_rxdata),
    .loopback_rxdatavalid(loopback_rxdatavalid),
    .loopback_rxstartblock(loopback_rxstartblock),
    .loopback_rxsyncheader(loopback_rxsyncheader),
    // ------------- output ----------------
    .serdes_pipe_txdatavalid(serdes_pipe_txdatavalid),
    .serdes_pipe_txdata(serdes_pipe_txdata),
    .serdes_pipe_txelecidle(serdes_pipe_txelecidle),
    .serdes_pipe_txdetectrx(serdes_pipe_txdetectrx)
  );

  serdes_pipe_rx
    u_serdes_pipe_rx (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .sync_hdr_bypass_en(sync_hdr_bypass_en_d),
    .rcvry_lock_state(rcvry_lock_state_d),
    .drift_buffer_en(drift_buffer_en_d),
    .drift_buffer_low_ptr_en(drift_buffer_low_ptr_en_d),
    .deskew_en(deskew_en_d),
    .deskew_complete(deskew_complete),
    .deskew_redo(deskew_redo_d),
    .skpos_interval_block_num(skpos_interval_block_num),
    .loopback_state(loopback_state_d),
    .poll_compliance_state(poll_compliance_state_d),
    .encdec_8b10b(encdec_8b10b_d),
    .pipe_rate(pipe_rate_d),
    .pipe_width(pipe_width_d),
    .pipe_srisen(pipe_srisen_d),
    .flit_mode_enable(flit_mode_enable),
    .serdes_pipe_rxdata(serdes_pipe_rxdata),
    .serdes_pipe_rxvalid(serdes_pipe_rxvalid),
    .serdes_pipe_rxstatus(serdes_pipe_rxstatus),
    .serdes_pipe_txdetectrx(serdes_pipe_txdetectrx),
    .orig_pipe_loopback_slave(orig_pipe_loopback_slave),
    .orig_pipe_rxpolarity(orig_pipe_rxpolarity),
    .orig_pipe_blockaligncontrol(orig_pipe_blockaligncontrol),
    .orig_pipe_elasticbuffermode(orig_pipe_elasticbuffermode),
    // ------------- output ----------------
    .deskew_ptr(deskew_ptr),
    .deskew_avail(deskew_avail),
    .deskew_aligned(deskew_aligned),
    .deskew_req(deskew_req),
    .os_corrected(os_corrected),
    .loopback_rxdata(loopback_rxdata),
    .loopback_rxdatavalid(loopback_rxdatavalid),
    .loopback_rxstartblock(loopback_rxstartblock),
    .loopback_rxsyncheader(loopback_rxsyncheader),
    .orig_pipe_rxdata(orig_pipe_rxdata),
    .orig_pipe_rxdatak(orig_pipe_rxdatak),
    .orig_pipe_rxvalid(orig_pipe_rxvalid),
    .orig_pipe_rxdatavalid(orig_pipe_rxdatavalid),
    .orig_pipe_rxstartblock(orig_pipe_rxstartblock),
    .orig_pipe_rxsyncheader(orig_pipe_rxsyncheader),
    .orig_pipe_os_found(orig_pipe_os_found),
    .orig_pipe_os_found_end(orig_pipe_os_found_end),
    .orig_pipe_rxstatus(orig_pipe_rxstatus),
    .serdes_pipe_rxready(serdes_pipe_rxready)
  );

endmodule: serdes_pipe_lane
