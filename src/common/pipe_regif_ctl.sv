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
// ---    $Revision: #16 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/pipe_regif_ctl.sv#16 $
// --------------------------------------------------------------------------------------------
// --- Module Description: Controller for PIPE register interface
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/pipe_regif_pkg.svh"

module pipe_regif_ctl

import pipe_regif_pkg::*;
#(
  parameter  INST = 0
) (
// ------------ inputs ----------------
  input logic          clk,
  input logic          rst_n,
  input logic          ce,
  input logic [7:0]    pbus,
  input logic          mst_ctl_req,
  input logic          mst_ctl_eor, // MST to CTL End-Of-Request
  input logic [11:0]   mst_ctl_addr,
  input logic [7:0]    mst_ctl_data,
  input logic          slv_ctl_ack,
  input logic [7:0]    slv_ctl_data,
  input logic [3:0]    rx_msgbus_write_buffer_depth,
`ifndef SYNTHESIS
  input logic          rate_chg,
`endif // SYNTHESIS
// ------------ outputs ---------------
  output logic [7:0]   mbus,
  output logic         pam4_restricted_levels_wr_ack_pending,
  output logic         ctl_req_pending,
  output logic         ctl_mst_ready,
  output logic         ctl_slv_req,
  output logic         ctl_slv_we,
  output logic         ctl_slv_upd,
  output logic [11:0]  ctl_slv_addr,
  output logic [7:0]   ctl_slv_data
);

  localparam  TP = `TP;

// --------------------------------------------------------------------------------
//  PBUS RX Command Decode
// --------------------------------------------------------------------------------
  logic [7:0]  pbus_d;

  always_ff @(posedge clk or negedge rst_n) begin: pbus_d_PROC
    if(!rst_n) begin
      pbus_d <= #TP '0;
    end
    else if(ce) begin
      pbus_d <= #TP pbus;
    end
  end: pbus_d_PROC

  enum logic [1:0] {PBUS_CMD, PBUS_RD_ADDR, PBUS_WR_ADDR, PBUS_DATA}  pbus_state, next_pbus_state;
  logic [MSGBUS_CMD_NUM-1:0]  pbus_cmd_id, pbus_dec_cmd_id, pre_pbus_dec_cmd_id;
  logic [3:0]                 pbus_high_addr;
  logic [7:0]                 pbus_low_addr;
  logic [7:0]                 pbus_data;
  assign pbus_cmd_id = (pbus_state == PBUS_CMD) ? pbus_dec_cmd_id : 'h0;
  assign ctl_slv_req = pbus_cmd_id[WR_UNCOM] || pbus_cmd_id[WR_COM] || pbus_cmd_id[RD];
  assign ctl_slv_we = pbus_cmd_id[WR_UNCOM] || pbus_cmd_id[WR_COM];
  assign ctl_slv_upd = pbus_cmd_id[WR_COM];
  assign ctl_slv_addr = {pbus_high_addr, pbus_low_addr};
  assign ctl_slv_data = pbus_data;

  always_comb begin: pre_pbus_dec_cmd_id_PROC
    pre_pbus_dec_cmd_id = '0;
    for(int i = 0; i < MSGBUS_CMD_NUM; i++) begin
      pre_pbus_dec_cmd_id[i] = (pbus_d[7:4] == MSGBUS_CMD[i]);
    end
  end: pre_pbus_dec_cmd_id_PROC

  always_comb begin: next_pbus_state_PROC
    case(1'h1)
      pre_pbus_dec_cmd_id[WR_UNCOM]: next_pbus_state = PBUS_WR_ADDR;
      pre_pbus_dec_cmd_id[WR_COM]: next_pbus_state = PBUS_WR_ADDR;
      pre_pbus_dec_cmd_id[RD]: next_pbus_state = PBUS_RD_ADDR;
      pre_pbus_dec_cmd_id[WR_ACK]: next_pbus_state = PBUS_CMD;
      default: next_pbus_state = PBUS_CMD;
    endcase
  end: next_pbus_state_PROC

  // ccx_fsm: ; pbus_state; PBUS_DATA->PBUS_RD_ADDR; "Redundant fsm transition."
  // ccx_fsm: ; pbus_state; PBUS_DATA->PBUS_WR_ADDR; "Redundant fsm transition."
  // ccx_fsm: ; pbus_state; PBUS_RD_ADDR->PBUS_WR_ADDR; "Redundant fsm transition."
  // ccx_fsm: ; pbus_state; PBUS_WR_ADDR->PBUS_CMD; "Redundant fsm transition."
  // ccx_fsm: ; pbus_state; PBUS_WR_ADDR->PBUS_RD_ADDR; "Redundant fsm transition."
  always_ff @(posedge clk or negedge rst_n) begin: pbus_cmd_fsm_PROC
    if(!rst_n) begin
      pbus_state <= #TP PBUS_CMD;
      pbus_dec_cmd_id <= #TP '0;
      pbus_high_addr <= #TP '0;
      pbus_low_addr <= #TP '0;
      pbus_data <= #TP '0;
    end
    else if(ce) begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: The rule reports a violation as the combinational and sequential parts of an FSM are described in same always block. In this code, the sequential and combinational parts of an FSM are separated. So, disable SpyGlass from reporting this error.
      case(pbus_state)
// spyglass enable_block STARC05-2.11.3.1
        PBUS_CMD: begin
          pbus_state <= #TP next_pbus_state;
          pbus_dec_cmd_id <= #TP pre_pbus_dec_cmd_id;
          pbus_high_addr <= #TP pbus_d[3:0];
        end
        PBUS_RD_ADDR: begin
          pbus_state <= #TP PBUS_CMD;
          pbus_low_addr <= #TP pbus_d;
        end
        PBUS_WR_ADDR: begin
          pbus_state <= #TP PBUS_DATA;
          pbus_low_addr <= #TP pbus_d;
        end
        PBUS_DATA: begin
          pbus_state <= #TP PBUS_CMD;
          pbus_data <= #TP pbus_d;
        end
      endcase
    end
  end: pbus_cmd_fsm_PROC

// --------------------------------------------------------------------------------
//  MBUS TX Command Request
// --------------------------------------------------------------------------------
  logic [MSGBUS_CMD_NUM-1:0]  mbus_cmd_id, mbus_req_cmd_id;
  logic                       mbus_wr_com_req;
  logic                       mbus_wr_uncom_req;
  logic                       mbus_wr_ack_req;
  logic                       mbus_rd_cpl_req;

  always_comb begin: mbus_req_cmd_id_PROC
    mbus_req_cmd_id = '0;
    mbus_req_cmd_id[WR_UNCOM] = mbus_wr_uncom_req;
    mbus_req_cmd_id[WR_COM] = mbus_wr_com_req;
    mbus_req_cmd_id[WR_ACK] = mbus_wr_ack_req;
    mbus_req_cmd_id[RD_CPL] = mbus_rd_cpl_req;
  end: mbus_req_cmd_id_PROC

// --------------------------------------------------------------------------------
//  MASTER WR_COM/WR_UNCOM Request
// --------------------------------------------------------------------------------
  logic  mbus_wr_uncom_en;

  always_comb begin: mbus_wr_uncom_com_req_PROC
    mbus_wr_uncom_req = '0;
    mbus_wr_com_req = '0;
    if(mst_ctl_req) begin
      mbus_wr_uncom_req = (mbus_wr_uncom_en) ? !mst_ctl_eor : 1'h0;
      mbus_wr_com_req = (mbus_wr_uncom_en) ? mst_ctl_eor : 1'h1;
    end
  end: mbus_wr_uncom_com_req_PROC

  always_comb begin: mbus_wr_uncom_en_PROC
    mbus_wr_uncom_en = 1'h0;
    mbus_wr_uncom_en = (rx_msgbus_write_buffer_depth >= 4'h1);
    mbus_wr_uncom_en = (rx_msgbus_write_buffer_depth >= 4'h2);
  end: mbus_wr_uncom_en_PROC

// --------------------------------------------------------------------------------
//  SLAVE RD_CPL Request
// --------------------------------------------------------------------------------
  logic  slv_ctl_ack_pending;

  always_ff @(posedge clk or negedge rst_n) begin: slv_ctl_ack_pending_PROC
    if(!rst_n) begin
      slv_ctl_ack_pending <= #TP '0;
    end
    else if(ce) begin
      if(pbus_cmd_id[RD]) begin
        slv_ctl_ack_pending <= #TP 1'h1;
      end
      else if(slv_ctl_ack) begin
        slv_ctl_ack_pending <= #TP 1'h0;
      end
    end
  end: slv_ctl_ack_pending_PROC

  logic [7:0]  slv_ctl_rdata;

  always_ff @(posedge clk or negedge rst_n) begin: slv_ctl_rdata_PROC
    if(!rst_n) begin
      slv_ctl_rdata <= #TP '0;
    end
    else if(ce) begin
      if(slv_ctl_ack) begin
        slv_ctl_rdata <= #TP slv_ctl_data;
      end
    end
  end: slv_ctl_rdata_PROC

  always_ff @(posedge clk or negedge rst_n) begin: mbus_rd_cpl_req_PROC
    if(!rst_n) begin
      mbus_rd_cpl_req <= #TP '0;
    end
    else if(ce) begin
      // ccx_cond: ; 0; 01+10; "Redundant condition. Due to current implementation of pipe_regif_slv."
      if(slv_ctl_ack_pending && slv_ctl_ack) begin
        mbus_rd_cpl_req <= #TP 1'h1;
      end
      else if(mbus_cmd_id[RD_CPL]) begin
        mbus_rd_cpl_req <= #TP 1'h0;
      end
    end
  end: mbus_rd_cpl_req_PROC

// --------------------------------------------------------------------------------
//  SLAVE WR_ACK Request
// --------------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin: mbus_wr_ack_req_PROC
    if(!rst_n) begin
      mbus_wr_ack_req <= #TP '0;
    end
    else if(ce) begin
      if(pbus_cmd_id[WR_COM]) begin
        mbus_wr_ack_req <= #TP 1'h1;
      end
      else if(mbus_cmd_id[WR_ACK]) begin
        mbus_wr_ack_req <= #TP 1'h0;
      end
    end
  end: mbus_wr_ack_req_PROC

// --------------------------------------------------------------------------------
//  MBUS TX Command Arbitration
// --------------------------------------------------------------------------------
  logic  mbus_wr_outstanding;

  always_ff @(posedge clk or negedge rst_n) begin: mbus_wr_outstanding_PROC
    if(!rst_n) begin
      mbus_wr_outstanding <= #TP '0;
    end
    else if(ce) begin
      if(mbus_cmd_id[WR_UNCOM]) begin
        mbus_wr_outstanding <= #TP 1'h1;
      end
      else if(mbus_cmd_id[WR_COM]) begin
        mbus_wr_outstanding <= #TP 1'h0;
      end
    end
  end: mbus_wr_outstanding_PROC

  logic  pbus_wr_ack_pending;
  assign ctl_req_pending = (|mbus_req_cmd_id) || pbus_wr_ack_pending;

  always_ff @(posedge clk or negedge rst_n) begin: pbus_wr_ack_pending_PROC
    if(!rst_n) begin
      pbus_wr_ack_pending <= #TP '0;
    end
    else if(ce) begin
      if(mbus_cmd_id[WR_COM]) begin
        pbus_wr_ack_pending <= #TP 1'h1;
      end
      else if(pbus_cmd_id[WR_ACK]) begin
        pbus_wr_ack_pending <= #TP 1'h0;
      end
    end
  end: pbus_wr_ack_pending_PROC

  logic [MSGBUS_CMD_NUM-1:0]  mbus_arb_cmd_id;
  logic                       mbus_slv_req;
  logic                       mbus_arb_mst_req;
  assign mbus_slv_req = mbus_req_cmd_id[WR_ACK] || mbus_req_cmd_id[RD_CPL];
  assign mbus_arb_mst_req = (mbus_wr_outstanding) ? 1'h1 :
                            (pbus_wr_ack_pending) ? 1'h0 :
                            (mbus_slv_req)        ? 1'h0 : 1'h1;

  always_ff @(posedge clk or negedge rst_n) begin: pam4_restricted_levels_wr_ack_pending_PROC
    if(!rst_n) begin
      pam4_restricted_levels_wr_ack_pending <= #TP '0;
    end
    else if(ce) begin
      if(mbus_cmd_id[WR_COM] && mst_ctl_addr == PHY_REG_INFO[PHY_RX_CONTROL1].addr) begin
        pam4_restricted_levels_wr_ack_pending <= #TP 1'h1;
      end
      else if(pbus_cmd_id[WR_ACK]) begin
        pam4_restricted_levels_wr_ack_pending <= #TP 1'h0;
      end
    end
  end: pam4_restricted_levels_wr_ack_pending_PROC

  struct packed {
    logic [2:0]       len;
    logic [2:0][7:0]  data;
  }  mbus_arb_dataset, mbus_dataset;

  always_comb begin: mbus_arb_cmd_id_dataset_PROC
    mbus_arb_cmd_id = '0;
    mbus_arb_dataset = '{len: 1'h0, data: {MSGBUS_CMD[NOP], 4'h0}};
    if(mbus_arb_mst_req) begin
      if(mbus_req_cmd_id[WR_UNCOM]) begin
        mbus_arb_cmd_id[WR_UNCOM] = 1'h1;
        mbus_arb_dataset = '{
          len: 3'b111,
          data: {mst_ctl_data, mst_ctl_addr[7:0], {MSGBUS_CMD[WR_UNCOM], mst_ctl_addr[11:8]}}};
      end
      else if(mbus_req_cmd_id[WR_COM]) begin
        mbus_arb_cmd_id[WR_COM] = 1'h1;
        mbus_arb_dataset = '{
          len: 3'b111,
          data: {mst_ctl_data, mst_ctl_addr[7:0], {MSGBUS_CMD[WR_COM], mst_ctl_addr[11:8]}}};
      end
    end
    else begin
      if(mbus_req_cmd_id[RD_CPL]) begin
        mbus_arb_cmd_id[RD_CPL] = 1'h1;
        mbus_arb_dataset = '{
          len: 2'b11, data: {slv_ctl_rdata, {MSGBUS_CMD[RD_CPL], 4'h0}}};
      end
      else if(mbus_req_cmd_id[WR_ACK]) begin
        mbus_arb_cmd_id[WR_ACK] = 1'h1;
        mbus_arb_dataset = '{len: 1'b1, data: {MSGBUS_CMD[WR_ACK], 4'h0}};
      end
    end
  end: mbus_arb_cmd_id_dataset_PROC

// --------------------------------------------------------------------------------
//  MBUS TX Command Generation
// --------------------------------------------------------------------------------
  // MBUS_EOC: M2P Message Bus End-Of-Command state.
  enum logic [1:0] {MBUS_IDLE, MBUS_EOC, MBUS_CMD}  mbus_state, next_mbus_state;
  logic  mbus_cmd_burst_en;
  logic  mbus_arb_data_en;
  logic  mbus_arb_data_len_gt_1;
  logic  mbus_data_len_le_3;
  logic  mbus_ready;
  assign next_mbus_state = (mbus_arb_data_len_gt_1) ? MBUS_CMD : MBUS_EOC;
  assign mbus_arb_data_en = mbus_arb_dataset.len[0];
  assign mbus_arb_data_len_gt_1 = mbus_arb_dataset.len[1];
  assign mbus_data_len_le_3 = !mbus_dataset.len[2];
  assign mbus_ready = (mbus_state == MBUS_IDLE) || ((mbus_state == MBUS_EOC) && mbus_cmd_burst_en);
  assign mbus_cmd_id = (mbus_ready) ? mbus_arb_cmd_id : 'h0;
  assign mbus = mbus_dataset.data[0];
  assign ctl_mst_ready = mbus_arb_mst_req && mbus_ready;
  assign mbus_cmd_burst_en = 1'h1;

  // ccx_fsm: ; mbus_state; MBUS_CMD->MBUS_IDLE; "Redundant fsm transition."
  always_ff @(posedge clk or negedge rst_n) begin: mbus_state_dataset_PROC
    if(!rst_n) begin
      mbus_state <= #TP MBUS_IDLE;
      mbus_dataset <= #TP '{len: 1'h0, data: {MSGBUS_CMD[NOP], 4'h0}};
    end
    else if(ce) begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: The rule reports a violation as the combinational and sequential parts of an FSM are described in same always block. In this code, the sequential and combinational parts of an FSM are separated. So, disable SpyGlass from reporting this error.
      case(mbus_state)
// spyglass enable_block STARC05-2.11.3.1
        MBUS_IDLE: begin
          if(mbus_arb_data_en) begin
            mbus_state <= #TP next_mbus_state;
            mbus_dataset <= #TP mbus_arb_dataset;
          end
        end
        MBUS_EOC: begin
          if(mbus_arb_data_en && mbus_cmd_burst_en) begin
            mbus_state <= #TP next_mbus_state;
            mbus_dataset <= #TP mbus_arb_dataset;
          end
          else begin
            mbus_state <= #TP MBUS_IDLE;
            mbus_dataset <= #TP '{len: 1'h0, data: {MSGBUS_CMD[NOP], 4'h0}};
          end
        end
        MBUS_CMD: begin
          if(mbus_data_len_le_3) begin
            mbus_state <= #TP MBUS_EOC;
          end
          mbus_dataset <= #TP '{
           len: {1'h0, mbus_dataset.len[2:1]}, data: {{MSGBUS_CMD[NOP], 4'h0}, mbus_dataset.data[2:1]}};
        end
      endcase
    end
  end: mbus_state_dataset_PROC


endmodule: pipe_regif_ctl
