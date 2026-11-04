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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_clksync.sv#13 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side clock synchronizer module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_clksync

  import serdes_pipe_pkg::*;
(
  // ---------- input (clk) --------------
  input logic                     clk,
  input logic                     rst_n,
  input logic                     sync_hdr_bypass_en,
  input logic                     drift_buffer_en,
  input logic                     deskew_aligned_to_unaligned,
  input logic [9:0]               skpos_interval_block_num,
  input logic                     loopback_state,
  input logic                     poll_compliance_state,
  input logic                     pipe_srisen,
  input logic                     flit_mode_enable,
  input logic [RATE_WD-1:0]       pipe_rate,
  input logic [WIDTH_WD-1:0]      pipe_width,
  input logic                     pipe_loopback_slave,
  input logic                     pipe_rxpolarity,
  input logic                     pipe_blockaligncontrol,
  input logic                     err_estore_overflow,
  input logic                     err_estore_underflow,
  // ---------- input (rx_clk) -----------
  input logic                     rx_clk,
  input logic                     rx_rst_n,
  // ---------- output (clk) -------------
  output logic                    buf_sync_rst,
  // ---------- output (rx_clk) ----------
  output logic                    sync_hdr_bypass_en_sync2rx,
  output logic                    drift_buffer_en_sync2rx,
  output logic                    deskew_aligned_to_unaligned_sync2rx,
  output logic [9:0]              skpos_interval_block_num_sync2rx,
  output logic                    loopback_state_sync2rx,
  output logic                    poll_compliance_state_sync2rx,
  output logic                    pipe_srisen_sync2rx,
  output logic                    flit_mode_enable_sync2rx,
  output logic [RATE_WD-1:0]      pipe_rate_sync2rx,
  output logic [WIDTH_WD-1:0]     pipe_width_sync2rx,
  output logic                    pipe_loopback_slave_sync2rx,
  output logic                    pipe_rxpolarity_sync2rx,
  output logic                    pipe_blockaligncontrol_sync2rx,
  output logic                    rx_sync_rst,
  output logic                    err_estore_overflow_sync2rx,
  output logic                    err_estore_underflow_sync2rx
);

// --------------------------------------------------------------------------------
//  Common internal parameter
// --------------------------------------------------------------------------------
  localparam int  BCM_NMR = 3; // BCM N-modular redundancy.

// --------------------------------------------------------------------------------
//  BCM: data bus synchronizer with acknowledge
// --------------------------------------------------------------------------------
  struct packed {
    logic [RATE_WD-1:0]      pipe_rate;
    logic [WIDTH_WD-1:0]     pipe_width;
    logic [9:0]              skpos_interval_block_num;
  }  pre_sync_bus_sdata, sync_bus_sdata;

  always_comb begin: pre_sync_bus_sdata_PROC
    pre_sync_bus_sdata.pipe_rate = pipe_rate;
    pre_sync_bus_sdata.pipe_width = pipe_width;
    pre_sync_bus_sdata.skpos_interval_block_num = skpos_interval_block_num;
  end

  always_comb begin: pipe_rate_sync2rx_PROC
    pipe_rate_sync2rx = sync_bus_sdata.pipe_rate;
    pipe_width_sync2rx = sync_bus_sdata.pipe_width;
    skpos_interval_block_num_sync2rx = sync_bus_sdata.skpos_interval_block_num;
  end

  DWC_pcie_ctl_bcm25
   #(
    .WIDTH($bits(pre_sync_bus_sdata)),
    .PEND_MODE(0),
    .ACK_DELAY(1),
    .F_SYNC_TYPE(SYNC_TYPE),
    .R_SYNC_TYPE(SYNC_TYPE),
    .VERIF_EN(1),
    .SEND_MODE(0),
    .SVA_TYPE(0)
  ) u_DWC_pcie_ctl_bcm25 (
    // ---------- input (clk) --------------
    .clk_s(clk),
    .rst_s_n(rst_n),
    .init_s_n(1'h1),
    .send_s(1'h1),
    .data_s(pre_sync_bus_sdata),
    // ---------- input (rx_clk) -----------
    .clk_d(rx_clk),
    .rst_d_n(rx_rst_n),
    .init_d_n(1'h1),
    // ---------- output (clk) -------------
    .empty_s(),
    .full_s(),
    .done_s(),
    // ---------- output (rx_clk) ----------
    .data_avail_d(),
    .data_d(sync_bus_sdata)
  );

// --------------------------------------------------------------------------------
//  BCM: dual clock signal synchronizer
// --------------------------------------------------------------------------------
  struct packed {
    logic  pipe_loopback_slave;
    logic  pipe_rxpolarity;
    logic  pipe_blockaligncontrol;
    logic  flit_mode_enable;
    logic  loopback_state;
    logic  poll_compliance_state;
    logic  pipe_srisen;
  }  pre_sync_sig_sdata, sync_sig_sdata;

  always_ff @(posedge clk or negedge rst_n) begin: pre_sync_sig_sdata_PROC
    if(!rst_n) begin
      pre_sync_sig_sdata <= #`TP '0;
    end
    else begin
      pre_sync_sig_sdata.pipe_loopback_slave <= #`TP pipe_loopback_slave;
      pre_sync_sig_sdata.pipe_rxpolarity <= #`TP pipe_rxpolarity;
      pre_sync_sig_sdata.pipe_blockaligncontrol <= #`TP pipe_blockaligncontrol;
      pre_sync_sig_sdata.flit_mode_enable <= #`TP flit_mode_enable;
      pre_sync_sig_sdata.loopback_state <= #`TP loopback_state;
      pre_sync_sig_sdata.poll_compliance_state <= #`TP poll_compliance_state;
      pre_sync_sig_sdata.pipe_srisen <= #`TP pipe_srisen;
    end
  end

  always_comb begin: sync_sig_sdata_PROC
    pipe_loopback_slave_sync2rx = sync_sig_sdata.pipe_loopback_slave;
    pipe_rxpolarity_sync2rx = sync_sig_sdata.pipe_rxpolarity;
    pipe_blockaligncontrol_sync2rx = sync_sig_sdata.pipe_blockaligncontrol;
    flit_mode_enable_sync2rx = sync_sig_sdata.flit_mode_enable;
    loopback_state_sync2rx = sync_sig_sdata.loopback_state;
    poll_compliance_state_sync2rx = sync_sig_sdata.poll_compliance_state;
    pipe_srisen_sync2rx = sync_sig_sdata.pipe_srisen;
  end

  DWC_pcie_ctl_bcm21
   #(
    .WIDTH($bits(pre_sync_sig_sdata)),
    .F_SYNC_TYPE(SYNC_TYPE),
    .VERIF_EN(1),
    .SVA_TYPE(0)
  ) u_DWC_pcie_ctl_bcm21 (
    // ---------- input (clk) --------------
    .data_s(pre_sync_sig_sdata),
    // ---------- input (rx_clk) -----------
    .clk_d(rx_clk),
    .rst_d_n(rx_rst_n),
    // ---------- output (rx_clk) ----------
    .data_d(sync_sig_sdata)
  );

  struct packed {
    logic  err_estore_overflow;
    logic  err_estore_underflow;
  }  pre_sync_pulse_sig_sdata, sync_pulse_sig_sdata;

  always_ff @(posedge clk or negedge rst_n) begin: pre_sync_pulse_sig_sdata_PROC
    if(!rst_n) begin
      pre_sync_pulse_sig_sdata <= #`TP '0;
    end
    else begin
      pre_sync_pulse_sig_sdata.err_estore_overflow <= #`TP err_estore_overflow;
      pre_sync_pulse_sig_sdata.err_estore_underflow <= #`TP err_estore_underflow;
    end
  end

  always_comb begin: sync_pulse_sig_sdata_PROC
    err_estore_overflow_sync2rx = sync_pulse_sig_sdata.err_estore_overflow;
    err_estore_underflow_sync2rx = sync_pulse_sig_sdata.err_estore_underflow;
  end

  DWC_pcie_ctl_bcm22
   #(
    .REG_EVENT    (1),
    .F_SYNC_TYPE  (SYNC_TYPE),
    .VERIF_EN     (1),
    .PULSE_MODE   (0)
  ) u_DWC_pcie_ctl_bcm22 [1:0] (
    // ---------- input (clk) --------------
    .clk_s        (clk),
    .rst_s_n      (rst_n),
    .init_s_n     (1'b1),
    .event_s      (pre_sync_pulse_sig_sdata),
    // ---------- input (rx_clk) -----------
    .clk_d        (rx_clk),
    .rst_d_n      (rx_rst_n),
    .init_d_n     (1'b1),
    // ---------- output (rx_clk) ----------
    .event_d      (sync_pulse_sig_sdata)
  );

// --------------------------------------------------------------------------------
//  BCM: single clock data bus synchronizer for automotive (ASIL-D)
// --------------------------------------------------------------------------------
 typedef struct packed {
    logic  sync_hdr_bypass_en;
    logic  drift_buffer_en;
  }  atvsig_t;

  atvsig_t                sync_atv_sig_sdata;
  atvsig_t [BCM_NMR-1:0]  pre_sync_atv_sig_sdata;

  always_ff @(posedge clk or negedge rst_n) begin: pre_sync_atv_sig_sdata_PROC
    if(!rst_n) begin
      pre_sync_atv_sig_sdata <= #`TP '0;
    end
    else begin
      for(int i = 0; i < BCM_NMR; i++) begin
        pre_sync_atv_sig_sdata[i].sync_hdr_bypass_en <= #`TP sync_hdr_bypass_en;
        pre_sync_atv_sig_sdata[i].drift_buffer_en <= #`TP drift_buffer_en;
      end
    end
  end

  always_comb begin: sync_atv_sig_sdata_PROC
    sync_hdr_bypass_en_sync2rx = sync_atv_sig_sdata.sync_hdr_bypass_en;
    drift_buffer_en_sync2rx = sync_atv_sig_sdata.drift_buffer_en;
  end

  // Automotive requirement: cxl_auto_8.
  DWC_pcie_ctl_bcm21_atv
   #(
    .WIDTH($bits(sync_atv_sig_sdata)),
    .F_SYNC_TYPE(SYNC_TYPE),
    .VERIF_EN(1),
    .SVA_TYPE(0),
    .TMR_CDC(1)
  ) u_DWC_pcie_ctl_bcm21_atv (
    // ---------- input (clk) --------------
    .data_s(pre_sync_atv_sig_sdata),
    // ---------- input (rx_clk) -----------
    .clk_d(rx_clk),
    .rst_d_n(rx_rst_n),
    // ---------- output (rx_clk) ----------
   .data_d (sync_atv_sig_sdata)
  );

  DWC_pcie_ctl_bcm22
   #(
    .REG_EVENT    (1),
    .F_SYNC_TYPE  (SYNC_TYPE),
    .VERIF_EN     (1),
    .PULSE_MODE   (0)
  ) u_DWC_pcie_ctl_bcm22_deskew (
    // ---------- input (clk) --------------
    .clk_s        (clk),
    .rst_s_n      (rst_n),
    .init_s_n     (1'b1),
    .event_s      (deskew_aligned_to_unaligned),
    // ---------- input (rx_clk) -----------
    .clk_d        (rx_clk),
    .rst_d_n      (rx_rst_n),
    .init_d_n     (1'b1),
    // ---------- output (rx_clk) ----------
    .event_d      (deskew_aligned_to_unaligned_sync2rx)
  );

// --------------------------------------------------------------------------------
//  BCM: reset synchronizer
// --------------------------------------------------------------------------------
  logic                chg_pipe_rate;
  logic [RATE_WD-1:0]  pipe_rate_d;
  assign chg_pipe_rate = (pipe_rate != pipe_rate_d);

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      pipe_rate_d <= #`TP '0;
    end
    else begin
      pipe_rate_d <= #`TP pipe_rate;
    end
  end

  logic  sync_rst, sync_rst_in_prog;
  assign sync_rst = chg_pipe_rate;
  assign buf_sync_rst = sync_rst || sync_rst_in_prog;

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
    .clr_d(sync_rst),
    // ---------- input (rx_clk) -----------
    .clk_s(rx_clk),
    .rst_s_n(rx_rst_n),
    .init_s_n(1'h1),
    .clr_s(1'h0),
    // ---------- output (clk) -------------
    .clr_in_prog_d(sync_rst_in_prog),
    .clr_sync_d(),
    .clr_cmplt_d(),
    // ---------- output (rx_clk) ----------
    .clr_sync_s(),
    .clr_in_prog_s(rx_sync_rst),
    .clr_cmplt_s()
  );

endmodule: serdes_pipe_rx_clksync
