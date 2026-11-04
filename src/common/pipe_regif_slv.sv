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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/pipe_regif_slv.sv#10 $
// --------------------------------------------------------------------------------------------
// --- Module Description: Slave controller for MAC registers
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/pipe_regif_pkg.svh"

module pipe_regif_slv

import pipe_regif_pkg::*;
#(
  parameter   TX_COEF_WD = 18,
  parameter   TX_FS_WD = 6,
  parameter   FOMFEEDBACK_WD = 8,
  parameter   DIRFEEDBACK_WD = `DIRFEEDBACK_WD,
  parameter   INST = 0
) (
  // ------------ inputs ----------------
  input logic                        clk,
  input logic                        rst_n,
  input logic                        ce,
  input logic                        ctl_slv_req,
  input logic                        ctl_slv_we,
  input logic                        ctl_slv_upd,
  input logic [11:0]                 ctl_slv_addr,
  input logic [7:0]                  ctl_slv_data,
  input logic                        mst_slv_sample_cnt_rst,
  input logic                        mst_slv_error_cnt_rst,
  input logic                        mst_slv_margin_offset_chg,
  input logic                        pipe_phystatus,
  input logic [2:0]                  pipe_rate,
// ------------ outputs ---------------
  output logic                       phystatus,
  output logic [TX_COEF_WD-1:0]      local_tx_pset_coef,
  output logic [TX_FS_WD-1:0]        localfs,
  output logic [TX_FS_WD-1:0]        locallf,
  output logic                       local_tx_coef_valid,
  output logic [FOMFEEDBACK_WD-1:0]  fomfeedback,
  output logic [DIRFEEDBACK_WD-1:0]  dirfeedback,
  output logic                       margin_status,
  output logic                       margin_nak,
  output logic [6:0]                 margin_sample_cnt,
  output logic [5:0]                 margin_error_cnt,
  output logic                       slv_ctl_ack,
  output logic [7:0]                 slv_ctl_data
);

  localparam  TP = `TP;

// --------------------------------------------------------------------------------
//  Lane Margining Specific Process
// --------------------------------------------------------------------------------
  logic  margin_cnt_mask;

  always_ff @(posedge clk or negedge rst_n) begin: margin_cnt_mask_PROC
    if(!rst_n) begin
      margin_cnt_mask <= #TP '0;
    end
    else if(ce) begin
      if(mst_slv_margin_offset_chg) begin
        margin_cnt_mask <= #TP 1'h1;
      end
      else if(margin_status || margin_nak) begin
        margin_cnt_mask <= #TP 1'h0;
      end
    end
  end: margin_cnt_mask_PROC

// --------------------------------------------------------------------------------
//  CONTROL Request Decode
// --------------------------------------------------------------------------------
  logic  wr_req, rd_req, upd_req;

  always_comb begin: wr_rd_upd_req_PROC
    {wr_req, rd_req, upd_req} = '0;
    if(ctl_slv_req) begin
      wr_req = ctl_slv_we;
      rd_req = ~ctl_slv_we;
      upd_req = ctl_slv_upd;
    end
  end: wr_rd_upd_req_PROC

  struct packed {
    logic [MAC_REG_NUM-1:0]       mac_reg;
  }  req_reg_id, wr_reg_id;

  always_comb begin: req_reg_id_PROC
    for(int i = 0; i < MAC_REG_NUM; i++) begin
      req_reg_id.mac_reg[i] = (ctl_slv_addr == MAC_REG_INFO[i].addr);
    end
  end: req_reg_id_PROC

  always_comb begin: wr_reg_id_PROC
    wr_reg_id = '0;
    if(wr_req) begin
      wr_reg_id = req_reg_id;
    end
    // Lane Margining count update is masked when Margin Offset is changed.
    // This is for backward compatibility with PIPE 4.4 specification.
    if(margin_cnt_mask) begin
      wr_reg_id.mac_reg[RX_MARGIN_STATUS1] = 1'h0;
      wr_reg_id.mac_reg[RX_MARGIN_STATUS2] = 1'h0;
    end
  end: wr_reg_id_PROC

// --------------------------------------------------------------------------------
//  MAC Register
// --------------------------------------------------------------------------------
  logic [MAC_REG_NUM-1:0]  clr_reg_id;
  logic [5:0]              reg_gen6_localfs;
  logic [5:0]              reg_gen6_locallf;
  logic [1:0]              reg_gen6_lefdch_cplus1;   // LinkEvalFeedbackDirectionChange C+1
  logic [1:0]              reg_gen6_lefdch_czero;    // LinkEvalFeedbackDirectionChange C
  logic [1:0]              reg_gen6_lefdch_cminus1;  // LinkEvalFeedbackDirectionChange C-1
  logic [1:0]              reg_gen6_lefdch_cminus2;  // LinkEvalFeedbackDirectionChange C-2
  logic [4:0]              reg_gen6_ltp_cplus1;      // Local Tx Pset C+1
  logic [5:0]              reg_gen6_ltp_czero;       // Local Tx Pset C
  logic [3:0]              reg_gen6_ltp_cminus1;     // Local Tx Pset C-1
  logic [2:0]              reg_gen6_ltp_cminus2;     // Local Tx Pset C-2

  always_comb begin: clr_reg_id_PROC
    clr_reg_id = '0;
    // Margin counts are cleared when clear requests are sent.
    clr_reg_id[RX_MARGIN_STATUS1] = mst_slv_sample_cnt_rst;
    clr_reg_id[RX_MARGIN_STATUS2] = mst_slv_error_cnt_rst;
  end: clr_reg_id_PROC

  struct packed {
    logic [MAC_REG_NUM-1:0][7:0]       mac_reg;
  }  reg_data;

  generate
    for(genvar i = 0; i < MAC_REG_NUM; i++) begin: mac_reg_inst_itr
      if(exists_mac_reg(mac_reg_e'(i))) begin: mac_reg_inst
        pipe_regif_mac_reg
         #(
          .REG_DEFAULT(MAC_REG_INFO[i].val),
          .REG_ATTR(MAC_REG_INFO[i].attr)
        ) u_pipe_regif_mac_reg (
          .clk(clk),
          .rst_n(rst_n),
          .ce(ce),
          .din(ctl_slv_data),
          .clr(clr_reg_id[i]),
          .we(wr_reg_id.mac_reg[i]),
          .upd(upd_req),
          .dout(reg_data.mac_reg[i])
        );
      end: mac_reg_inst
      else begin: rsvd_mac_reg_inst
        assign reg_data.mac_reg[i] = 8'h0;
      end: rsvd_mac_reg_inst
    end: mac_reg_inst_itr
  endgenerate

// Align with bit width acoding to PCIe base spec
assign reg_gen6_lefdch_czero   = f_encoding_lefdch(reg_data.mac_reg[RX_LINK_EVALUATION_STATUS3][2:0]);
assign reg_gen6_lefdch_cplus1  = f_encoding_lefdch(reg_data.mac_reg[RX_LINK_EVALUATION_STATUS3][6:4]);
assign reg_gen6_lefdch_cminus1 = f_encoding_lefdch(reg_data.mac_reg[RX_LINK_EVALUATION_STATUS2][6:4]);
assign reg_gen6_lefdch_cminus2 = f_encoding_lefdch(reg_data.mac_reg[RX_LINK_EVALUATION_STATUS2][2:0]);
// at gen6 rate we need to fit four coefficients into the same 18 bits we use for Gen3/4/5
// this logic is used to extract the lower bits from each register and to saturate their
// value if the MSBs are greater than zero
// Note that in PIPE 6.0 has actually more MSBs than PIPE 6.1, e.g.
// PIPE 6.0 : MSBs are TX_STATUS2[7:5]
// PIPE 6.1 : MSBs are TX_STATUS2[5:5] while TX_STATUS2[7:6] is reserved and default to zero
// the logic below will work in both cases
assign reg_gen6_ltp_cplus1   = (|reg_data.mac_reg[TX_STATUS2][7:5]) ? {5{1'b1}} : reg_data.mac_reg[TX_STATUS2][4:0];
assign reg_gen6_ltp_czero    = (|reg_data.mac_reg[TX_STATUS1][7:6]) ? {6{1'b1}} : reg_data.mac_reg[TX_STATUS1][5:0];
assign reg_gen6_ltp_cminus1  = (|reg_data.mac_reg[TX_STATUS0][7:4]) ? {4{1'b1}} : reg_data.mac_reg[TX_STATUS0][3:0];
assign reg_gen6_ltp_cminus2  = (|reg_data.mac_reg[TX_STATUS7][7:3]) ? {3{1'b1}} : reg_data.mac_reg[TX_STATUS7][2:0];
assign reg_gen6_localfs      = (|reg_data.mac_reg[TX_STATUS8][7:6]) ? {6{1'b1}} : reg_data.mac_reg[TX_STATUS8][5:0];
assign reg_gen6_locallf      = (|reg_data.mac_reg[TX_STATUS9][7:6]) ? {6{1'b1}} : reg_data.mac_reg[TX_STATUS9][5:0];


// --------------------------------------------------------------------------------
//  MAC Register to P2M Ouput Mapping
// --------------------------------------------------------------------------------
  logic  eq_complete;
  logic  req_fomfeedback, req_dirfeedback, req_feedback_d;
  assign req_fomfeedback = wr_reg_id.mac_reg[RX_LINK_EVALUATION_STATUS0];
  assign req_dirfeedback = wr_reg_id.mac_reg[RX_LINK_EVALUATION_STATUS1];
  logic  req_dirfeedback_g6;
  assign req_dirfeedback_g6 = wr_reg_id.mac_reg[RX_LINK_EVALUATION_STATUS2] || wr_reg_id.mac_reg[RX_LINK_EVALUATION_STATUS3];
  assign phystatus = pipe_phystatus || eq_complete;

  always_ff @(posedge clk or negedge rst_n) begin: req_feedback_d_PROC
    if(!rst_n) begin
      req_feedback_d <= #TP '0;
    end
    else if (ce) begin
      if(upd_req) begin
        req_feedback_d <= #TP 1'h0;
      end
      else if(req_fomfeedback || req_dirfeedback || req_dirfeedback_g6) begin
        req_feedback_d <= #TP 1'h1;
      end
    end
  end: req_feedback_d_PROC

  always_ff @(posedge clk or negedge rst_n) begin: eq_complete_PROC
    if(!rst_n) begin
      eq_complete <= #TP 'h0;
    end
    else if (ce) begin
      if(upd_req) begin
        eq_complete <= #TP (req_fomfeedback || req_dirfeedback || req_feedback_d || req_dirfeedback_g6);
      end
      else begin
        eq_complete <= #TP 1'h0;
      end
    end
  end: eq_complete_PROC

  logic  req_local_tx_coef, req_local_tx_coef_d;
  assign req_local_tx_coef = (wr_reg_id.mac_reg[TX_STATUS2] || wr_reg_id.mac_reg[TX_STATUS1] || wr_reg_id.mac_reg[TX_STATUS0] || wr_reg_id.mac_reg[TX_STATUS7]);

  always_ff @(posedge clk or negedge rst_n) begin: req_local_tx_coef_d_PROC
    if(!rst_n) begin
      req_local_tx_coef_d <= #TP 'h0;
    end
    else if (ce) begin
      if(upd_req) begin
        req_local_tx_coef_d <= #TP 1'h0;
      end
      else if(req_local_tx_coef) begin
        req_local_tx_coef_d <= #TP 1'h1;
      end
    end
  end: req_local_tx_coef_d_PROC

  always_ff @(posedge clk or negedge rst_n) begin: local_tx_coef_valid_PROC
    if(!rst_n) begin
      local_tx_coef_valid <= #TP 'h0;
    end
    else if (ce) begin
      if(upd_req) begin
        local_tx_coef_valid <= #TP (req_local_tx_coef || req_local_tx_coef_d);
      end
      else begin
        local_tx_coef_valid <= #TP 1'h0;
      end
    end
  end: local_tx_coef_valid_PROC

  always_comb begin: local_fs_lf_PROC
    case(pipe_rate)
      `GEN3_RATE: {localfs, locallf} = {reg_data.mac_reg[TX_STATUS3][5:0], reg_data.mac_reg[TX_STATUS4][5:0]};
      `GEN4_RATE: {localfs, locallf} = {reg_data.mac_reg[TX_STATUS5][5:0], reg_data.mac_reg[TX_STATUS6][5:0]};
      `GEN5_RATE: {localfs, locallf} = {reg_data.mac_reg[RX_STATUS4][5:0], reg_data.mac_reg[RX_STATUS5][5:0]};
      `GEN6_RATE: {localfs, locallf} = {reg_gen6_localfs, reg_gen6_locallf};
      default: {localfs, locallf} = '0;
    endcase
  end: local_fs_lf_PROC

  assign local_tx_pset_coef = 
    (pipe_rate == `GEN6_RATE) ? {reg_gen6_ltp_cplus1, reg_gen6_ltp_czero, reg_gen6_ltp_cminus1, reg_gen6_ltp_cminus2} :
    {reg_data.mac_reg[TX_STATUS2][5:0], reg_data.mac_reg[TX_STATUS1][5:0], reg_data.mac_reg[TX_STATUS0][5:0]};

  assign fomfeedback = reg_data.mac_reg[RX_LINK_EVALUATION_STATUS0];
  assign dirfeedback = 
//  Gen6     = {C+1[1:0], C-2[2:0], C-1[2:0]}
//  Gen3/4/5 = {C+1[1:0], C0[1:0], C-1[1:0]}
    (pipe_rate == `GEN6_RATE) ? {reg_gen6_lefdch_cplus1, reg_gen6_lefdch_cminus2, reg_gen6_lefdch_cminus1} :
                       reg_data.mac_reg[RX_LINK_EVALUATION_STATUS1][5:0]
                       ;
  assign margin_status = reg_data.mac_reg[RX_MARGIN_STATUS0][0];
  assign margin_nak = reg_data.mac_reg[RX_MARGIN_STATUS0][1];
  assign margin_sample_cnt = reg_data.mac_reg[RX_MARGIN_STATUS1][6:0];
  assign margin_error_cnt = reg_data.mac_reg[RX_MARGIN_STATUS2][5:0];

// --------------------------------------------------------------------------------
//  SLAVE to CONTROL Read Completion Generation
// --------------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin: slv_ctl_ack_PROC
    if(!rst_n) begin
      slv_ctl_ack <= #TP '0;
    end
    else if(ce) begin
      if(rd_req) begin
        slv_ctl_ack <= #TP 1'h1;
      end
    end
  end: slv_ctl_ack_PROC

  logic [7:0]  pre_slv_ctl_data;

  always_comb begin: pre_slv_ctl_data_PROC
    pre_slv_ctl_data = '0;
    for(int i = 0; i < MAC_REG_NUM; i++) begin
      if(req_reg_id.mac_reg[i]) begin
        pre_slv_ctl_data = reg_data.mac_reg[i];
      end
    end
  end: pre_slv_ctl_data_PROC

  always_ff @(posedge clk or negedge rst_n) begin: slv_ctl_data_PROC
    if(!rst_n) begin
      slv_ctl_data <= #TP '0;
    end
    else if(ce) begin
      slv_ctl_data <= #TP pre_slv_ctl_data;
    end
  end: slv_ctl_data_PROC

// --------------------------------------------------------------------------------
//  Task
// --------------------------------------------------------------------------------
// Function to build a encoding for LinkEvalFeedbackDirectionChange
function automatic [1:0] f_encoding_lefdch;
  input  [2:0] in_data;
begin
    case (in_data)
        3'b101,                             // Increment by 4
        3'b011,                             // Increment by 4
        3'b001 : f_encoding_lefdch = 2'b01; // Increment by 1
        3'b110,                             // Decrement by 4
        3'b100,                             // Decrement by 2
        3'b010 : f_encoding_lefdch = 2'b10; // Decrement by 1
        default: f_encoding_lefdch = 2'b00; // No change
    endcase
end
endfunction // f_encoding_lefdch

endmodule: pipe_regif_slv
