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
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/pipe_regif_mst.sv#14 $
// --------------------------------------------------------------------------------------------
// --- Module Description: Master controller for PHY registers
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/pipe_regif_pkg.svh"

module pipe_regif_mst

import pipe_regif_pkg::*;
#(
  parameter  TX_FS_WD = 6,
  parameter  PSET_ID_WD = `PSET_ID_WD,
  parameter  INST = 0
) (
// ------------ inputs ----------------
  input logic                   clk,
  input logic                   rst_n,
  input logic                   ce,
  input logic                   lpif_dvalid,
  input logic                   pam4_restricted_levels_requirement,
  input logic [17:0]            txdeemph,
  input logic                   txdeemph_dvalid,
  input logic [2:0]             txmargin,
  input logic                   txswing,
  input logic [TX_FS_WD-1:0]    fs,
  input logic [TX_FS_WD-1:0]    lf,
  input logic [PSET_ID_WD-1:0]  local_pset_index,
  input logic                   getlocal_pset_coef,
  input logic                   rxeqinprogress,
  input logic                   invalid_req,
  input logic                   rxeqeval,
  input logic [2:0]             margin_cmd,
  input logic [6:0]             margin_offset,
  input logic [1:0]             margin_cnt_rst,
  input logic [2:0]             pipe_rate,
  input logic                   pam4_restricted_levels,
  input logic                   ctl_mst_ready,
// ------------ outputs ---------------
  output logic                  mst_slv_sample_cnt_rst,
  output logic                  mst_slv_error_cnt_rst,
  output logic                  mst_slv_margin_offset_chg,
  output logic                  mst_req_pending,
  output logic                  mst_ctl_req,
  output logic                  mst_ctl_eor,
  output logic [11:0]           mst_ctl_addr,
  output logic [7:0]            mst_ctl_data
);

  localparam  TP = `TP;
  localparam  MAX_REQ_NUM = 3 + 1;

// --------------------------------------------------------------------------------
//  MAC2PHY Input to PHY Register Mapping
// --------------------------------------------------------------------------------
  logic [7:0]  data_phy_tx_control2;
  logic [7:0]  data_phy_tx_control3;
  logic [7:0]  data_phy_tx_control4;
  logic [7:0]  data_phy_tx_control9;

  struct packed {
    logic [PHY_REG_NUM-1:0][7:0]       phy_reg;
  }  m2p_reg_data, req_reg_data;

  always_comb begin: m2p_reg_data_PROC
    m2p_reg_data = '0;
    data_phy_tx_control2 = 0;
    data_phy_tx_control3 = 0;
    data_phy_tx_control4 = 0;
    data_phy_tx_control9 = 0;

  if(pipe_rate == `GEN6_RATE) begin
    data_phy_tx_control2 = {4'h0, txdeemph[6:3]};   // C-1
    data_phy_tx_control3 = {2'h0, txdeemph[12:7]};  // C0
    data_phy_tx_control4 = {3'h0, txdeemph[17:13]}; // C+1
    data_phy_tx_control9 = {5'h0, txdeemph[2:0]};   // C-2
  end else
  begin
    data_phy_tx_control2 = {2'h0, txdeemph[5:0]};
    data_phy_tx_control3 = {2'h0, txdeemph[11:6]};
    data_phy_tx_control4 = {2'h0, txdeemph[17:12]};
    data_phy_tx_control9 = req_reg_data.phy_reg[PHY_TX_CONTROL9];
  end

    m2p_reg_data.phy_reg[RX_MARGIN_CONTROL0] = {4'h0, margin_cnt_rst, (~margin_cmd[2] & margin_cmd[0]), margin_cmd[0]};
    m2p_reg_data.phy_reg[RX_MARGIN_CONTROL1] = {margin_cmd[1], margin_offset};
    m2p_reg_data.phy_reg[PHY_RX_CONTROL1] = {5'h0, pam4_restricted_levels_requirement ? pam4_restricted_levels : 1'h0, 2'h0};
    m2p_reg_data.phy_reg[PHY_RX_CONTROL3] = {5'h0, invalid_req, rxeqinprogress, rxeqeval};
    m2p_reg_data.phy_reg[PHY_TX_CONTROL2] = data_phy_tx_control2;
    m2p_reg_data.phy_reg[PHY_TX_CONTROL3] = data_phy_tx_control3;
    m2p_reg_data.phy_reg[PHY_TX_CONTROL4] = data_phy_tx_control4;
    m2p_reg_data.phy_reg[PHY_TX_CONTROL5] = {getlocal_pset_coef, 1'h0, local_pset_index};
    m2p_reg_data.phy_reg[PHY_TX_CONTROL6] = {2'h0, fs};
    m2p_reg_data.phy_reg[PHY_TX_CONTROL7] = {2'h0, lf};
    m2p_reg_data.phy_reg[PHY_TX_CONTROL8] = {4'h0, txswing, txmargin};
    m2p_reg_data.phy_reg[PHY_TX_CONTROL9] = data_phy_tx_control9;
  end: m2p_reg_data_PROC

// --------------------------------------------------------------------------------
//  PHY Shadow Register
// --------------------------------------------------------------------------------
  logic [PHY_REG_NUM-1:0][7:0]  phy_reg_den;

  always_comb begin: lpif_den_PROC
    phy_reg_den = (lpif_dvalid) ? '1 : '0;
    if(!txdeemph_dvalid) begin
      phy_reg_den[PHY_TX_CONTROL2] = '0;
      phy_reg_den[PHY_TX_CONTROL3] = '0;
      phy_reg_den[PHY_TX_CONTROL4] = '0;
      phy_reg_den[PHY_TX_CONTROL9] = '0;
    end
    if(!getlocal_pset_coef) begin
      phy_reg_den[PHY_TX_CONTROL5][5:0] = '0;
    end
  end: lpif_den_PROC

  logic [2:0] pipe_rate_d;
  logic rate_change_goe_g6_pulse;
  always_ff @(posedge clk or negedge rst_n) begin: pipe_rate_d_PROC
    if(!rst_n) begin
      pipe_rate_d <= #TP '0;
    end else begin
      pipe_rate_d <= #TP pipe_rate;
    end
  end: pipe_rate_d_PROC

  assign rate_change_goe_g6_pulse = pipe_rate >= `GEN6_RATE && pipe_rate_d < `GEN6_RATE;


  logic [PHY_REG_NUM-1:0][7:0] clr_reg_id;
  always_comb begin: clr_reg_id_PROC
    clr_reg_id = '0;
    clr_reg_id[PHY_RX_CONTROL1][2] = pam4_restricted_levels_requirement ? rate_change_goe_g6_pulse : 1'b0;
  end: clr_reg_id_PROC

  struct packed {
    logic [PHY_REG_NUM-1:0]       phy_reg;
  }  req_reg_id, arb_reg_id, ack_reg_id;
  assign  mst_req_pending = (|req_reg_id);

  generate
    for(genvar i = 0; i < PHY_REG_NUM; i++) begin: phy_shadow_reg_inst_itr
      if(exists_phy_reg(phy_reg_e'(i))) begin: phy_shadow_reg_inst
        pipe_regif_phy_shadow_reg
         #(
          .REG_DEFAULT(PHY_REG_INFO[i].val),
          .REG_ATTR(PHY_REG_INFO[i].attr)
        ) u_pipe_regif_phy_shadow_reg (
          .clk(clk),
          .rst_n(rst_n),
          .ce(ce),
          .clr(clr_reg_id[i]),
          .din(m2p_reg_data.phy_reg[i]),
          .den(phy_reg_den[i]),
          .ack(ack_reg_id.phy_reg[i]),
          .dout(req_reg_data.phy_reg[i]),
          .req(req_reg_id.phy_reg[i])
        );
      end: phy_shadow_reg_inst
      else begin: rsvd_phy_reg_inst
        assign req_reg_id.phy_reg[i] = 1'h0;
        assign req_reg_data.phy_reg[i] = 8'h0;
      end: rsvd_phy_reg_inst
    end: phy_shadow_reg_inst_itr
  endgenerate


// --------------------------------------------------------------------------------
//  Lane Margining Specific Process
// --------------------------------------------------------------------------------
  logic  req_start_margin, start_margin_d;
  logic  start_margining;
  assign req_start_margin = req_reg_data.phy_reg[RX_MARGIN_CONTROL0][0];
  assign start_margining = !start_margin_d && req_start_margin;

  always_ff @(posedge clk or negedge rst_n) begin: start_margin_d_PROC
    if(!rst_n) begin
      start_margin_d <= #TP '0;
    end
    else if(ce) begin
      if(ack_reg_id.phy_reg[RX_MARGIN_CONTROL0]) begin
        start_margin_d <= #TP req_start_margin;
      end
    end
  end: start_margin_d_PROC

  always_ff @(posedge clk or negedge rst_n) begin: mst_slv_sample_error_cnt_rst_PROC
    if(!rst_n) begin
      mst_slv_sample_cnt_rst <= #TP '0;
      mst_slv_error_cnt_rst <= #TP '0;
    end
    else if(ce) begin
      if(ack_reg_id.phy_reg[RX_MARGIN_CONTROL0]) begin
        mst_slv_error_cnt_rst <= #TP req_reg_data.phy_reg[RX_MARGIN_CONTROL0][2];
        mst_slv_sample_cnt_rst <= #TP req_reg_data.phy_reg[RX_MARGIN_CONTROL0][3];
      end
      else begin
        mst_slv_error_cnt_rst <= #TP 1'h0;
        mst_slv_sample_cnt_rst <= #TP 1'h0;
      end
    end
  end: mst_slv_sample_error_cnt_rst_PROC

  logic [6:0]  req_margin_offset, margin_offset_d;
  assign req_margin_offset = req_reg_data.phy_reg[RX_MARGIN_CONTROL1][6:0];

  always_ff @(posedge clk or negedge rst_n) begin: margin_offset_d_PROC
    if(!rst_n) begin
      margin_offset_d <= #TP '0;
    end
    else if(ce) begin
      if(ack_reg_id.phy_reg[RX_MARGIN_CONTROL1]) begin
        margin_offset_d <= #TP req_margin_offset;
      end
    end
  end: margin_offset_d_PROC

  always_comb begin: mst_slv_margin_offset_chg_PROC
    mst_slv_margin_offset_chg = '0;
    if(ack_reg_id.phy_reg[RX_MARGIN_CONTROL1]) begin
      mst_slv_margin_offset_chg = (margin_offset_d != req_margin_offset);
    end
  end: mst_slv_margin_offset_chg_PROC

// --------------------------------------------------------------------------------
//  MASTER to CONTROL Request Arbitration
// --------------------------------------------------------------------------------
  struct packed {
    logic [MAX_REQ_NUM-1:0]        len;
    logic [MAX_REQ_NUM-1:0][7:0]   data;
    logic [MAX_REQ_NUM-1:0][11:0]  addr;
  }  arb_dataset, mst_ctl_dataset;

  always_comb begin: arb_reg_id_data_PROC
    arb_reg_id = '0;
    arb_dataset = '{default: '0};
    if(1'h0) begin
      // This field is dummy for coreConsultant code generation.
    end
    // PAM4RestrictedLevels is granted preferentially.
    // The deassertion should be earlier than RxEqEval assertion for Eq.Phase23 bypass case
    else if(req_reg_id.phy_reg[PHY_RX_CONTROL1]) begin
      arb_reg_id.phy_reg[PHY_RX_CONTROL1] = 1'h1;
      arb_dataset = '{
        len: 1'b1,
        data: req_reg_data.phy_reg[PHY_RX_CONTROL1],
        addr: PHY_REG_INFO[PHY_RX_CONTROL1].addr};
    end
    // RxEqEval is granted preferentially.
    else if(req_reg_id.phy_reg[PHY_RX_CONTROL3]) begin
      arb_reg_id.phy_reg[PHY_RX_CONTROL3] = 1'h1;
      arb_dataset = '{
        len: 1'b1,
        data: req_reg_data.phy_reg[PHY_RX_CONTROL3],
        addr: PHY_REG_INFO[PHY_RX_CONTROL3].addr};
    end
    // TxSwing is granted preferentially than TxDeemph.
    else if(req_reg_id.phy_reg[PHY_TX_CONTROL8]) begin
      arb_reg_id.phy_reg[PHY_TX_CONTROL8] = 1'h1;
      arb_dataset = '{
        len: 1'b1,
        data: req_reg_data.phy_reg[PHY_TX_CONTROL8],
        addr: PHY_REG_INFO[PHY_TX_CONTROL8].addr};
    end
    // TxDeemph is granted preferentially.
//ccx_cond: ; 0; 0001; Redundant condition. if PHY_TX_CONTROL9 regiter is written with PHY_TX_CONTROL2-3 register.
    else if(req_reg_id.phy_reg[PHY_TX_CONTROL2] ||
            req_reg_id.phy_reg[PHY_TX_CONTROL3] || req_reg_id.phy_reg[PHY_TX_CONTROL4] || (req_reg_id.phy_reg[PHY_TX_CONTROL9] && (pipe_rate == `GEN6_RATE))) begin
      arb_reg_id.phy_reg[PHY_TX_CONTROL2] = 1'h1;
      arb_reg_id.phy_reg[PHY_TX_CONTROL3] = 1'h1;
      arb_reg_id.phy_reg[PHY_TX_CONTROL4] = 1'h1;
      if(pipe_rate == `GEN6_RATE) begin
          arb_reg_id.phy_reg[PHY_TX_CONTROL9] = 1'h1;
        arb_dataset = '{
          len: 4'b1111,
          data: {req_reg_data.phy_reg[PHY_TX_CONTROL9], req_reg_data.phy_reg[PHY_TX_CONTROL4],
                 req_reg_data.phy_reg[PHY_TX_CONTROL3], req_reg_data.phy_reg[PHY_TX_CONTROL2]},
          addr: {PHY_REG_INFO[PHY_TX_CONTROL9].addr, PHY_REG_INFO[PHY_TX_CONTROL4].addr,
                 PHY_REG_INFO[PHY_TX_CONTROL3].addr, PHY_REG_INFO[PHY_TX_CONTROL2].addr}};
      end else
      begin  
        arb_dataset = '{
          len: 3'b111,
          data: {req_reg_data.phy_reg[PHY_TX_CONTROL4],
                 req_reg_data.phy_reg[PHY_TX_CONTROL3], req_reg_data.phy_reg[PHY_TX_CONTROL2]},
          addr: {PHY_REG_INFO[PHY_TX_CONTROL4].addr,
                 PHY_REG_INFO[PHY_TX_CONTROL3].addr, PHY_REG_INFO[PHY_TX_CONTROL2].addr}};
      end
    end
    else if(req_reg_id.phy_reg[PHY_TX_CONTROL6] || req_reg_id.phy_reg[PHY_TX_CONTROL7]) begin
      arb_reg_id.phy_reg[PHY_TX_CONTROL6] = 1'h1;
      arb_reg_id.phy_reg[PHY_TX_CONTROL7] = 1'h1;
      arb_dataset = '{
        len: 2'b11,
        data: {req_reg_data.phy_reg[PHY_TX_CONTROL7], req_reg_data.phy_reg[PHY_TX_CONTROL6]},
        addr: {PHY_REG_INFO[PHY_TX_CONTROL7].addr, PHY_REG_INFO[PHY_TX_CONTROL6].addr}};
    end
    // Margin Direction and Margin Offset are sent when start margining occurs.
    // This is for backward compatibility with PIPE 4.4 specification.
    else if((req_reg_id.phy_reg[RX_MARGIN_CONTROL0] && req_reg_id.phy_reg[RX_MARGIN_CONTROL1]) || start_margining) begin
      arb_reg_id.phy_reg[RX_MARGIN_CONTROL1] = 1'h1;
      arb_reg_id.phy_reg[RX_MARGIN_CONTROL0] = 1'h1;
      arb_dataset = '{
        len: 2'b11,
        data: {req_reg_data.phy_reg[RX_MARGIN_CONTROL0], req_reg_data.phy_reg[RX_MARGIN_CONTROL1]},
        addr: {PHY_REG_INFO[RX_MARGIN_CONTROL0].addr, PHY_REG_INFO[RX_MARGIN_CONTROL1].addr}};
    end
    else begin
      for(int i = 0; i < PHY_REG_NUM; i++) begin
        if(req_reg_id.phy_reg[i]) begin
          arb_reg_id = '0;
          arb_reg_id.phy_reg[i] = 1'h1;
          arb_dataset = '{
            len: 1'b1,
            data: req_reg_data.phy_reg[i],
            addr: PHY_REG_INFO[i].addr};
        end
      end
    end
  end: arb_reg_id_data_PROC

// --------------------------------------------------------------------------------
//  MASTER to CONTROL Request Generation
// --------------------------------------------------------------------------------
  enum logic [1:0] {MST_CTL_IDLE, MST_CTL_BUSY}  mst_ctl_state;
  logic  arb_data_en;
  logic  mst_ctl_data_len_le_2;
  assign arb_data_en = arb_dataset.len[0];
  assign mst_ctl_data_len_le_2 = !mst_ctl_dataset.len[1];
  assign ack_reg_id = (mst_ctl_state == MST_CTL_IDLE) ? arb_reg_id : '0;
  assign mst_ctl_req = mst_ctl_dataset.len[0];
  assign mst_ctl_eor = mst_ctl_data_len_le_2 && (mst_ctl_state == MST_CTL_BUSY);
  assign mst_ctl_data = mst_ctl_dataset.data[0];
  assign mst_ctl_addr = mst_ctl_dataset.addr[0];

  always_ff @(posedge clk or negedge rst_n) begin: mst_ctl_state_dataset_PROC
    if(!rst_n) begin
      mst_ctl_state <= #TP MST_CTL_IDLE;
      mst_ctl_dataset <= #TP '{default: '0};
    end
    else if(ce) begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: The rule reports a violation as the combinational and sequential parts of an FSM are described in same always block. In this code, the sequential and combinational parts of an FSM are separated. So, disable SpyGlass from reporting this error.
      case(mst_ctl_state)
// spyglass enable_block STARC05-2.11.3.1
        MST_CTL_IDLE: begin
          if(arb_data_en) begin
            mst_ctl_state <= #TP MST_CTL_BUSY;
            mst_ctl_dataset <= #TP arb_dataset;
          end
        end
        MST_CTL_BUSY: begin
          if(ctl_mst_ready) begin
            if(mst_ctl_data_len_le_2) begin
              mst_ctl_state <= #TP MST_CTL_IDLE;
            end
            mst_ctl_dataset <= #TP '{
              len: {1'h0, mst_ctl_dataset.len[MAX_REQ_NUM-1:1]},
              data: {8'h0, mst_ctl_dataset.data[MAX_REQ_NUM-1:1]},
              addr: {12'h0, mst_ctl_dataset.addr[MAX_REQ_NUM-1:1]}};
          end
        end
      endcase
    end
  end: mst_ctl_state_dataset_PROC

endmodule: pipe_regif_mst
