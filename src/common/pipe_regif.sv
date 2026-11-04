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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/pipe_regif.sv#10 $
// --------------------------------------------------------------------------------------------
// --- Module Description: PIPE Register Interface for PIPE Message Bus
// --------------------------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 module pipe_regif #(
  parameter   TX_COEF_WD = 18,
  parameter   TX_FS_WD = 6,
  parameter   PSET_ID_WD = `PSET_ID_WD,
  parameter   FOMFEEDBACK_WD = 8,
  parameter   DIRFEEDBACK_WD = `DIRFEEDBACK_WD,
  parameter   INST = 0
  ) (
  // ------------ inputs ----------------
  input logic                        clk,
  input logic                        rst_n,
  input logic                        clk_en,
  input logic                        lpif_mst_dvalid,
  input  [3:0]                       rx_msgbus_write_buffer_depth,
  input logic                        pam4_restricted_levels_requirement,
  input logic [17:0]                 lpif_txdeemph,
  input logic                        lpif_txdeemph_dvalid,
  input logic [2:0]                  lpif_txmargin,
  input logic                        lpif_txswing,
  input logic                        pipe_phystatus,
  input logic [2:0]                  pipe_rate,
  input logic [TX_FS_WD-1:0]         lpif_fs,
  input logic [TX_FS_WD-1:0]         lpif_lf,
  input logic [PSET_ID_WD-1:0]       lpif_local_pset_index,
  input logic                        lpif_getlocal_pset_coef,
  input logic                        lpif_rxeqinprogress,
  input logic                        lpif_invalid_req,
  input logic                        lpif_rxeqeval,
  input logic [2:0]                  lpif_margin_cmd,
  input logic [6:0]                  lpif_margin_offset,
  input logic [1:0]                  lpif_margin_cnt_rst,
  input logic                        pam4_restricted_levels,
`ifndef SYNTHESIS
  input logic                        rate_chg,
`endif // SYNTHESIS
  input logic  [7:0]                 pipe_p2m_msgbus,
// ------------ outputs ---------------
  output logic                       lpif_phystatus,
  output logic [TX_COEF_WD-1:0]      lpif_local_tx_pset_coef,
  output logic [TX_FS_WD-1:0]        lpif_localfs,
  output logic [TX_FS_WD-1:0]        lpif_locallf,
  output logic                       lpif_local_tx_coef_valid,
  output logic [FOMFEEDBACK_WD-1:0]  lpif_fomfeedback,
  output logic [DIRFEEDBACK_WD-1:0]  lpif_dirfeedback,
  output logic                       lpif_margin_status,
  output logic                       lpif_margin_nak,
  output logic [6:0]                 lpif_margin_sample_cnt,
  output logic [5:0]                 lpif_margin_error_cnt,
  output logic                       pam4_restricted_levels_wr_ack_pending,
  output logic                       pipe_regif_busy,
  output logic  [7:0]                pipe_m2p_msgbus
);

  localparam  TP = `TP;

  logic         ctl_mst_ready;
  logic         mst_ctl_req;
  logic         mst_ctl_eor;
  logic [11:0]  mst_ctl_addr;
  logic [7:0]   mst_ctl_data;
  logic         slv_ctl_ack;
  logic [7:0]   slv_ctl_data;
  logic         ctl_slv_req;
  logic         ctl_slv_we;
  logic         ctl_slv_upd;
  logic [11:0]  ctl_slv_addr;
  logic [7:0]   ctl_slv_data;
  logic         mst_req_pending;
  logic         ctl_req_pending;
  logic         mst_slv_sample_cnt_rst;
  logic         mst_slv_error_cnt_rst;
  logic         mst_slv_margin_offset_chg;
  assign pipe_regif_busy = mst_req_pending || ctl_req_pending;

// --------------------------------------------------------------------------------
//  Register interface controller
// --------------------------------------------------------------------------------
  pipe_regif_ctl
   #(
    .INST(INST)
  ) u_pipe_regif_ctl (
  // ------------ inputs ----------------
    .clk(clk),
    .rst_n(rst_n),
    .ce(clk_en),
    .pbus(pipe_p2m_msgbus),
    .mst_ctl_req(mst_ctl_req),
    .mst_ctl_eor(mst_ctl_eor),
    .mst_ctl_addr(mst_ctl_addr),
    .mst_ctl_data(mst_ctl_data),
    .slv_ctl_ack(slv_ctl_ack),
    .slv_ctl_data(slv_ctl_data),
    .rx_msgbus_write_buffer_depth(rx_msgbus_write_buffer_depth),
`ifndef SYNTHESIS
    .rate_chg(rate_chg),
`endif // SYNTHESIS
  // ------------ outputs ---------------
    .mbus(pipe_m2p_msgbus),
    .pam4_restricted_levels_wr_ack_pending(pam4_restricted_levels_wr_ack_pending),
    .ctl_req_pending(ctl_req_pending),
    .ctl_mst_ready(ctl_mst_ready),
    .ctl_slv_req(ctl_slv_req),
    .ctl_slv_we(ctl_slv_we),
    .ctl_slv_upd(ctl_slv_upd),
    .ctl_slv_addr(ctl_slv_addr),
    .ctl_slv_data(ctl_slv_data)
  );

// --------------------------------------------------------------------------------
//  Master controller for PHY register
// --------------------------------------------------------------------------------
  pipe_regif_mst
   #(
    .TX_FS_WD(TX_FS_WD),
    .PSET_ID_WD(PSET_ID_WD),
    .INST(INST)
  ) u_pipe_regif_mst (
  // ------------ inputs ----------------
    .clk(clk),
    .rst_n(rst_n),
    .ce(clk_en),
    .lpif_dvalid(lpif_mst_dvalid),
    .pam4_restricted_levels_requirement(pam4_restricted_levels_requirement),
    .txdeemph(lpif_txdeemph),
    .txdeemph_dvalid(lpif_txdeemph_dvalid),
    .txmargin(lpif_txmargin),
    .txswing(lpif_txswing),
    .fs(lpif_fs),
    .lf(lpif_lf),
    .local_pset_index(lpif_local_pset_index),
    .getlocal_pset_coef(lpif_getlocal_pset_coef),
    .rxeqinprogress(lpif_rxeqinprogress),
    .invalid_req(lpif_invalid_req),
    .rxeqeval(lpif_rxeqeval),
    .margin_cmd(lpif_margin_cmd),
    .margin_offset(lpif_margin_offset),
    .margin_cnt_rst(lpif_margin_cnt_rst),
    .pipe_rate(pipe_rate),
    .pam4_restricted_levels(pam4_restricted_levels),
    .ctl_mst_ready(ctl_mst_ready),
// ------------ outputs ---------------
    .mst_slv_sample_cnt_rst(mst_slv_sample_cnt_rst),
    .mst_slv_error_cnt_rst(mst_slv_error_cnt_rst),
    .mst_slv_margin_offset_chg(mst_slv_margin_offset_chg),
    .mst_req_pending(mst_req_pending),
    .mst_ctl_req(mst_ctl_req),
    .mst_ctl_eor(mst_ctl_eor),
    .mst_ctl_addr(mst_ctl_addr),
    .mst_ctl_data(mst_ctl_data)
  );

// --------------------------------------------------------------------------------
//  Slave controller for MAC register
// --------------------------------------------------------------------------------
  pipe_regif_slv
   #(
    .TX_COEF_WD(TX_COEF_WD),
    .TX_FS_WD(TX_FS_WD),
    .FOMFEEDBACK_WD(FOMFEEDBACK_WD),
    .DIRFEEDBACK_WD(DIRFEEDBACK_WD),
    .INST(INST)
  ) u_pipe_regif_slv (
  // ------------ inputs ----------------
    .clk(clk),
    .rst_n(rst_n),
    .ce(clk_en),
    .ctl_slv_req(ctl_slv_req),
    .ctl_slv_we(ctl_slv_we),
    .ctl_slv_upd(ctl_slv_upd),
    .ctl_slv_addr(ctl_slv_addr),
    .ctl_slv_data(ctl_slv_data),
    .mst_slv_sample_cnt_rst(mst_slv_sample_cnt_rst),
    .mst_slv_error_cnt_rst(mst_slv_error_cnt_rst),
    .mst_slv_margin_offset_chg(mst_slv_margin_offset_chg),
    .pipe_phystatus(pipe_phystatus),
    .pipe_rate(pipe_rate),
  // ------------ outputs ---------------
    .phystatus(lpif_phystatus),
    .local_tx_pset_coef(lpif_local_tx_pset_coef),
    .localfs(lpif_localfs),
    .locallf(lpif_locallf),
    .local_tx_coef_valid(lpif_local_tx_coef_valid),
    .fomfeedback(lpif_fomfeedback),
    .dirfeedback(lpif_dirfeedback),
    .margin_status(lpif_margin_status),
    .margin_nak(lpif_margin_nak),
    .margin_sample_cnt(lpif_margin_sample_cnt),
    .margin_error_cnt(lpif_margin_error_cnt),
    .slv_ctl_ack(slv_ctl_ack),
    .slv_ctl_data(slv_ctl_data)
  );

endmodule: pipe_regif
