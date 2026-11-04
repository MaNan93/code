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
// ---    $DateTime: 2024/02/10 02:59:45 $
// ---    $Revision: #15 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_fc_merge.sv#15 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module performs FC merging for Flit Mode data path. 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_fc_merge
  import  xtlh_ms_pkg::xtlh_merge_pkt_struct;
  import  xtlh_ms_pkg::xtlh_vc_pkt_struct;
  import  xtlh_ms_pkg::count_dw;
  import  xtlh_ms_pkg::P_NDW;
  import  xtlh_ms_pkg::P_N_SHIFT_MERGE;
  import  xtlh_ms_pkg::P_MERGE_MAX_CNT;
  import  xtlh_ms_pkg::P_MERGE_MAX_CNT_WD;
  import  xtlh_ms_pkg::P_NW_CNT_WD;
    import xtlh_ms_pkg::P_NW_PROT;
  import  xtlh_ms_pkg::P_MERGE_NW;
  import  DWC_pcie_core_pkg::xtlh_pkt_t;
  import  cx_pl_pkg::P_NW;
  import  cx_pl_pkg::P_NFM_NW;
    import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
      import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter   TP                      = `TP,
  parameter   RAS_DP_PROT_CHK_ID_BASE = 0
) 
                      (
  input                                       core_clk,
  input                                       core_rst_n,
  input   [1:0]                               cons_packet_limit,            // Number of consecutive packets to accumulate before requesting stall of other FC's
                                                                            // 00 - 1
                                                                            // 01 - 2
                                                                            // 10 - 4
                                                                            // 11 - 7

  input                                       stall_req_in,                 // Request to stall this FC
  input                                       block_req_in,                 // Request to block this FC
  input                                       lp_req,
  input                                       intf,                         // 1 - Interface 1, 0 Interface 0, used to generate the posted response for the correct port in multi-port
  input                                       fc_init_done,                 // FC Init Complete
  input                                       rstctl_core_flush_req,        // Reset Flush
  input                                       halt_in,                      // Downstream halt
  input   xtlh_pkt_t                          pkt_in,                       // TLP interface
  input                                       flit_mode_en,                 // Enable FLIT Mode
  input                                       flit_marker_sent,             // Flit Marker has been sent
  output  logic                               xtlh_fc_merge_pkt_sot_last,   // SOT comes last
  output  logic                               xtlh_fc_merge_pkt_eot_last,   // EOT comes last
  input                                       flit_pack_limit,
  output  logic [P_NW_CNT_WD - 1 : 0]         xtlh_fc_merge_sot_cnt,        // Number of SOT in the current cycle
  output  logic [P_MERGE_MAX_CNT_WD - 1 : 0]  xtlh_fc_merge_tlp_count,      // Number of SOT in the shifter
  output  xtlh_vc_pkt_struct                  xtlh_fc_merge_pkt_out,        // Merged TLP's
  output  logic                               xtlh_fc_merge_halt_out,       // Packet interface halt
  output  logic                               xtlh_fc_merge_pending
  ,
  input  ras_dp_err_inj_t                     ras_dp_err_inj
  ,
  output ras_dp_err_log_t                     ras_dp_err_log
);

localparam  P_NFM_NW_CHUNKS = (P_MERGE_NW - (P_MERGE_NW % P_NFM_NW)) / P_NFM_NW;
localparam  P_OF_INDEX = 10;

xtlh_merge_pkt_struct                       int_merge_pkt_out;
xtlh_merge_pkt_struct                       int_merge_pkt_out_r;
xtlh_vc_pkt_struct                          int_fc_merge_fm_pkt_out;
logic                                       int_of_stall_req_r;
logic [P_NW_CNT_WD - 1 : 0]                 int_fc_merge_sot_cnt;
logic                                       int_stall_req_in_r;
logic                                       int_stall_req_fe;
logic                                       int_tlp_limit;
logic                                       int_block_nfm_tlp;
logic                                       int_accum_halt;
logic                                       int_flit_marker_r;
logic                                       int_req_flit_marker;
logic [P_MERGE_MAX_CNT_WD - 1 : 0]          int_fc_merge_tlp_count;
logic [2 : 0]                               int_max_tlp_limit;

logic [P_N_SHIFT_MERGE * 8 - 1 : 0]         int_pad_dwen;
logic [P_N_SHIFT_MERGE * 8 - 1 : 0]         int_accum_pad_dwen;
logic                                       int_en_accum_tlp;
xtlh_merge_pkt_struct                       int_p0_m_pkt;
xtlh_merge_pkt_struct [P_N_SHIFT_MERGE-1:0] int_p0_sm_pkt;
xtlh_merge_pkt_struct [P_N_SHIFT_MERGE-1:0] int_p0_accum_pkt;
xtlh_merge_pkt_struct                       int_nop_merge_pkt;
xtlh_merge_pkt_struct                       int_p0_merge_pkt_mux;

logic [P_N_SHIFT_MERGE - 1 : 0]             int_accum_p0_sel_r;
logic [P_N_SHIFT_MERGE - 1 : 0]             int_accum_p0_found;
xtlh_merge_pkt_struct                       int_accum_p0_merge_pkt_mux;

logic [P_N_SHIFT_MERGE - 1 : 0]             int_p0_found;
logic [P_N_SHIFT_MERGE - 1 : 0]             int_sm_p0_sel_r;
logic                                       int_dwen_pend;
logic                                       int_dwen_accum;
logic                                       int_en_pipe;
logic [P_NFM_NW - 1 : 0]                    int_merge_nfm_sot [P_NFM_NW_CHUNKS - 1 : 0];
logic [P_NFM_NW - 1 : 0]                    int_merge_nfm_eot [P_NFM_NW_CHUNKS - 1 : 0];
logic [2 : 0]                               int_sot_out_cnt_r;
logic                                       int_tlp_in_progress_r;
logic [P_MERGE_MAX_CNT_WD-1:0]              overflow_tlps_r;
logic                                       int_fm_limit;
logic                                       int_fc_init_pend;

logic [10:0]                                int_tlp_len;
// TLP Length is needed to calculate the CRC over the STP Token
xtlh_tlp_len_calc
 u_tlp_len_calc(
  .core_clk             (core_clk),
  .core_rst_n           (core_rst_n),
  .halt_in              (xtlh_fc_merge_halt_out),
  .pkt_in               (pkt_in)
  ,
  .flit_mode_en         (flit_mode_en)
  ,
  .xtlh_tlp_len         (int_tlp_len)
);

// RASDP checker insertion before the merge_fm/nfm modules
xtlh_pkt_t          pkt_in_chk;

xtlh_pkt_pipe_ms
 #(
  .N                  (1),
  .PIPE               (0),               // Number of stages of the delay module 
  .CAN_STALL          (0)
    ,
    .BUS_PROTECT_CHK_EN (1),
    .BUS_PROTECT_GEN_EN (0),
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE)
  ) u_xtlh_pkt0_pipe_chk_ms (
  .clk                       (core_clk),
  .rst_n                     (core_rst_n),
  .in_pkt                    (pkt_in),
  .out_halt                  (),
  .out_pkt                   (pkt_in_chk),
  .in_halt                   (1'b0)
    ,.ras_dp_err_log         (ras_dp_err_log)
      ,.ras_dp_err_inj       (ras_dp_err_inj)
);

assign xtlh_fc_merge_pkt_sot_last = int_fc_merge_fm_pkt_out.sot > int_fc_merge_fm_pkt_out.eot;
assign xtlh_fc_merge_pkt_eot_last = int_fc_merge_fm_pkt_out.eot > int_fc_merge_fm_pkt_out.sot;

// Reduce the number of TLP's that could be packed depending on potential overflow
// If TLP ongoing calculate the potential overflow the incoming TLP's will be limited based on the overflow
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    overflow_tlps_r <= #TP 'd0;
  else begin
    if(!halt_in && flit_mode_en) begin
      // More than 1 TLP may have overflowed in the last cycle if overflow in current cycle increase limit by worst case overflow 
      if((overflow_tlps_r > 0) && ((xtlh_fc_merge_pkt_out.sot > xtlh_fc_merge_pkt_out.eot))) begin
        overflow_tlps_r <= #TP P_MERGE_MAX_CNT - 3;
      end else begin
        // S or DATA
        if((((int_merge_pkt_out_r.eot == 0) && (int_merge_pkt_out_r.sot != 0)) || ((int_merge_pkt_out_r.eot == 0) && (int_merge_pkt_out_r.sot == 0))) && int_merge_pkt_out_r.dv)
          overflow_tlps_r <= #TP 'd1;
        // ESES
        else if(((int_merge_pkt_out_r.eot[P_NW-1:P_NW-5]) < (int_merge_pkt_out_r.sot[P_NW-1:P_NW-5])) && !(^int_merge_pkt_out_r.eot[P_NW-1:P_NW-5]) && (|int_merge_pkt_out_r.eot[P_NW-1:P_NW-5]) && !(^int_merge_pkt_out_r.sot[P_NW-1:P_NW-5]) && (|int_merge_pkt_out_r.sot[P_NW-1:P_NW-5]))
          overflow_tlps_r <= #TP 'd3;
        // SES or SESE
        else if(!(^int_merge_pkt_out_r.sot[P_NW-1:P_NW-5]) && (|int_merge_pkt_out_r.sot[P_NW-1:P_NW-5]))
          overflow_tlps_r <= #TP 'd2;
        // ES || ESE
        else if(((int_merge_pkt_out_r.eot[P_NW-1:P_NW-5]) < (int_merge_pkt_out_r.sot[P_NW-1:P_NW-5])) && ((!(^int_merge_pkt_out_r.eot[P_NW-1:P_NW-5]) && (|int_merge_pkt_out_r.eot[P_NW-1:P_NW-5])) || (|int_merge_pkt_out_r.eot[P_NW-1:P_NW-5])) && (^int_merge_pkt_out_r.sot[P_NW-1:P_NW-5]))
          overflow_tlps_r <= #TP 'd2;
        // SE || S || E
        else if((|int_merge_pkt_out_r.eot[P_NW-1:P_NW-5]) || (|int_merge_pkt_out_r.sot[P_NW-1:P_NW-5]))
          overflow_tlps_r <= #TP 'd1;
        // Data
        else if((int_merge_pkt_out_r.eot[P_NW-1:P_NW-5] == 0) && (int_merge_pkt_out_r.sot[P_NW-1:P_NW-5] == 0) && int_merge_pkt_out_r.dv)
          overflow_tlps_r <= #TP 'd1;
        else if(xtlh_fc_merge_pkt_out.sot > xtlh_fc_merge_pkt_out.eot)
          overflow_tlps_r <= #TP 'd1;
        else
          overflow_tlps_r <= #TP 'd0;
      end
    end
  end
end
assign int_fm_limit = (int_fc_merge_tlp_count >= ((P_MERGE_MAX_CNT - 1) - overflow_tlps_r)) || int_of_stall_req_r;

// If overflow occured previously and an new TLP was detected in the next cycle stall for 1 cycle to allow
// the ongoing TLP to complete before starting a new TLP
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_of_stall_req_r  <= #TP 1'b0;
  else begin
    if(!halt_in && !(|int_merge_pkt_out.dwen[2*P_NW-1:P_NW]))
      int_of_stall_req_r  <= #TP 1'b0;
    else if((|overflow_tlps_r) && (xtlh_fc_merge_pkt_out.sot > xtlh_fc_merge_pkt_out.eot) && int_merge_pkt_out.dv)
      int_of_stall_req_r  <= #TP 1'b1;
  end
end

// TLP In progress indication
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_tlp_in_progress_r <= #TP 1'b0;
  else begin
    if(int_tlp_in_progress_r && !xtlh_fc_merge_halt_out && pkt_in_chk.eot)
      int_tlp_in_progress_r <= #TP 1'b0;
    else if(!xtlh_fc_merge_halt_out && pkt_in_chk.sot && !pkt_in_chk.eot)
      int_tlp_in_progress_r <= #TP 1'b1;
  end
end


assign int_fc_init_pend = rstctl_core_flush_req ? 1'b0 : !fc_init_done;

logic int_flit_pack_stall_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_flit_pack_stall_r   <= #TP 1'b0;
  else begin
    if(!flit_pack_limit || (!xtlh_fc_merge_halt_out && !(|int_merge_pkt_out.dwen[(P_MERGE_NW - 1) : P_NW])))
      int_flit_pack_stall_r <= #TP 1'b0;
    else if(flit_pack_limit && (|int_merge_pkt_out.dwen))
      int_flit_pack_stall_r <= #TP 1'b1;
  end
end

// Generate the Halt for the Packet Interface
always_comb begin : halt_PROC
  if(flit_mode_en) begin
    xtlh_fc_merge_halt_out = int_accum_halt                                                                                   // Accumulation of data in the shift register
                                || (block_req_in && !int_tlp_in_progress_r)                                                   // Request to Block TLP's 
                                || (lp_req && !int_tlp_in_progress_r)                                                         // Low Power Entry Request
                                || int_fc_init_pend                                                                           // FC Initialization was not complete, if flushing ignore fc init
                                || (int_fm_limit && !int_tlp_in_progress_r)                                                   // Flit Packing Rules requires halt
                                || ((flit_pack_limit || int_flit_pack_stall_r) && !int_tlp_in_progress_r)                     // Flit framing halt request
                                || ((int_tlp_limit && stall_req_in) && !int_tlp_in_progress_r);                               // Stalling to allow another FC to progress
  end else begin
    xtlh_fc_merge_halt_out = int_accum_halt                                                                                   // Accumulation of data in the shift register
                                || (block_req_in && !int_tlp_in_progress_r)                                                   // Request to Block TLP's
                                || (lp_req && !int_tlp_in_progress_r)                                                         // Low Power Entry Request
                                || int_fc_init_pend                                                                           // FC Initialization was not complete, if flushing ignore fc init
                                || int_block_nfm_tlp;                                                                         // Non Flit Mode restrictions
  end
end : halt_PROC

assign xtlh_fc_merge_pending = int_merge_pkt_out.dv || int_merge_pkt_out_r.dv || xtlh_fc_merge_pkt_out.dv;

// Set a flag indicating a flit marker is pending clear it when the flit marker was inserted
// This is to avoid packing more TLP's in the flit carrying the end of the TLP requiring Flit Marker
assign int_req_flit_marker = flit_mode_en && (|int_merge_pkt_out.badeot || |(int_merge_pkt_out.ep & int_merge_pkt_out.eot));

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_flit_marker_r <= #TP '0;
  else begin
    if(int_req_flit_marker)
      int_flit_marker_r <= #TP '1;
    else if(flit_marker_sent)
      int_flit_marker_r <= #TP '0;
  end
end

// Flit Marker Accumulated or shift register need to offload
assign int_accum_halt = (flit_mode_en && int_flit_marker_r) || (|int_merge_pkt_out_r.dwen[(P_MERGE_NW - 1) : (2*P_NW)]) || ((|int_merge_pkt_out_r.dwen[(2*P_NW) - 1 : P_NW]) && halt_in);

assign int_dwen_pend = |int_merge_pkt_out_r.dwen;

assign int_en_pipe = !xtlh_fc_merge_halt_out || int_dwen_pend;
// RASDP generator insertion after the merge_fm/nfm modules
xtlh_merge_pipe_ms
 #(
  .N                  (1),
  .PIPE               (1),               // Number of stages of the delay module
  .CAN_STALL          (0)
    ,
    .BUS_PROTECT_CHK_EN (0),
    .BUS_PROTECT_GEN_EN (1),
    .RAS_DP_PROT_CHK_ID_BASE ('0)
  ) u_xtlh_merge_pipe_gen_ms (
  .clk                       (core_clk),
  .rst_n                     (core_rst_n),
  .in_pkt                    (int_merge_pkt_out),
  .enable                    (int_en_pipe),
  .out_halt                  (),
  .out_pkt                   (int_merge_pkt_out_r),
  .in_halt                   (1'b0)
    ,.ras_dp_err_log         ()
      ,.ras_dp_err_inj       ('0)
);

assign int_dwen_accum = |int_merge_pkt_out_r.dwen[P_MERGE_NW - 1 : P_NW];

assign xtlh_fc_merge_pkt_out = int_fc_merge_fm_pkt_out;

assign int_fc_merge_sot_cnt = flit_mode_en ? count_dw(int_merge_pkt_out.sot[P_NW-1:0]) : 0;

delay_n_w_enable
 #(
  .N        (1),
  .WD       (P_NW_CNT_WD),
  .RESETVAL (0)
) u_sot_cnt_pipe (
  .clk     (core_clk),
  .rst_n   (core_rst_n),
  .clear   (1'b0),
  .en      (int_en_pipe),
  .din     (int_fc_merge_sot_cnt),
  .dout    (xtlh_fc_merge_sot_cnt));

// Packet Output Interface
always_comb begin : pkt_out_PROC
  int_fc_merge_fm_pkt_out.sot = int_merge_pkt_out_r.sot[P_NW - 1 : 0];
  int_fc_merge_fm_pkt_out.soh = int_merge_pkt_out_r.soh[P_NW - 1 : 0];
  int_fc_merge_fm_pkt_out.data = int_merge_pkt_out_r.data[P_NW - 1 : 0];
  int_fc_merge_fm_pkt_out.dwen = int_merge_pkt_out_r.dwen[P_NW - 1 : 0];
  int_fc_merge_fm_pkt_out.eot = int_merge_pkt_out_r.eot[P_NW - 1 : 0];
  int_fc_merge_fm_pkt_out.intf = int_merge_pkt_out_r.intf[P_NW - 1 : 0];
  int_fc_merge_fm_pkt_out.dv = int_merge_pkt_out_r.dv;
  int_fc_merge_fm_pkt_out.ep = int_merge_pkt_out_r.ep[P_NW - 1 : 0];
  int_fc_merge_fm_pkt_out.badeot = int_merge_pkt_out_r.badeot[P_NW - 1 : 0];
  int_fc_merge_fm_pkt_out.ptm = int_merge_pkt_out_r.ptm[P_NW - 1 : 0];
  int_fc_merge_fm_pkt_out.is_from_dma = int_merge_pkt_out_r.is_from_dma[P_NW - 1 : 0];
  int_fc_merge_fm_pkt_out.pme_to_ack = int_merge_pkt_out_r.pme_to_ack[P_NW - 1 : 0];
  int_fc_merge_fm_pkt_out.is_from_msg_gen = int_merge_pkt_out_r.is_from_msg_gen[P_NW - 1 : 0];
    int_fc_merge_fm_pkt_out.ras_dp_err_inband_kbd = int_merge_pkt_out_r.ras_dp_err_inband_kbd;
    int_fc_merge_fm_pkt_out.tlp_prot = int_merge_pkt_out_r.tlp_prot;
  int_fc_merge_fm_pkt_out.tlp_len = int_merge_pkt_out_r.tlp_len[P_NW - 1 : 0];
end : pkt_out_PROC

logic [P_NFM_NW_CHUNKS - 1 : 0] int_tlp_cant_fit;
logic                           int_nfm_tlp_cant_fit;

// Determine if a TLP can merge or not in Non-Flit Mode
// Split the merged SOT/EOT into chunks of Non-flit NW and if we see sot ahead of eot in any block the new TLP
always_comb begin : nfm_tlp_block_PROC
  for(int i = 0; i < P_NFM_NW_CHUNKS; i++) begin
    int_merge_nfm_sot[i] = int_merge_pkt_out_r.sot[i*P_NFM_NW +: P_NFM_NW];
    int_merge_nfm_eot[i] = int_merge_pkt_out_r.eot[i*P_NFM_NW +: P_NFM_NW];
    int_tlp_cant_fit[i] = (int_merge_nfm_sot[i] > 0) && (int_merge_nfm_eot[i] > 0) && (!int_merge_nfm_eot[i][P_NFM_NW - 1]);
  end
end : nfm_tlp_block_PROC

// Any TLP In upper part of shift register with sot/eot combination that would prevent merging or TLP in lower part with pipeline full
assign int_nfm_tlp_cant_fit = (|int_tlp_cant_fit[P_NFM_NW_CHUNKS-1:1]) || (int_tlp_cant_fit[0] && halt_in);

// When there is a new SOT consider the following restrictions for Non-Flit Mode
// Single cycle nullified TLP presented with content remaining in the shift
// TLP Cant fit due to SOT/EOT framing rules for XDLH
// Nullified or Poisoned TLP in the shift
assign int_block_nfm_tlp = ((int_merge_pkt_out_r.dv && pkt_in_chk.badeot) || (int_nfm_tlp_cant_fit) || ((|int_merge_pkt_out_r.badeot) || (|(int_merge_pkt_out_r.ep & int_merge_pkt_out_r.eot)))) && (pkt_in_chk.sot);

// Generating Back-Pressure for fairness
assign int_tlp_limit = flit_mode_en && (int_sot_out_cnt_r == int_max_tlp_limit);

assign int_stall_req_fe = int_stall_req_in_r && !stall_req_in;

// SOT counter
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    int_sot_out_cnt_r   <= #TP '0;
    int_stall_req_in_r  <= #TP '0;
  end else begin
    if(flit_mode_en) begin
      int_stall_req_in_r  <= #TP stall_req_in;
      // Other interface granted reset the count or if the shift register is empty or contains EOT without SOT 
      if(int_stall_req_fe || !int_merge_pkt_out.dv || (int_merge_pkt_out.eot[P_NW-1:0] > int_merge_pkt_out.sot[P_NW-1:0]))
        int_sot_out_cnt_r  <= #TP '0;
      // Saturate the count
      else if(int_sot_out_cnt_r == int_max_tlp_limit)
        int_sot_out_cnt_r  <= #TP int_sot_out_cnt_r;
      else if(!halt_in && (|xtlh_fc_merge_pkt_out.sot))
        int_sot_out_cnt_r  <= #TP int_sot_out_cnt_r + 1;
      else
        int_sot_out_cnt_r  <= #TP int_sot_out_cnt_r;
    end else begin
      int_stall_req_in_r  <= #TP 1'b0;
      int_sot_out_cnt_r   <= #TP '0;
    end
  end
end

// Shift Register
always_comb begin : fc_merge_proc
  int_merge_pkt_out = int_merge_pkt_out_r;
  if(!xtlh_fc_merge_halt_out) begin
    // accumulate only no shift out
    if(halt_in) begin
      int_merge_pkt_out = int_accum_p0_merge_pkt_mux;
    // Shift and merge
    end else begin
      int_merge_pkt_out = int_p0_merge_pkt_mux;
    end
  end else begin
    // If there is data remaining and the interface is not halted shift out the remaining data
    if(!halt_in) begin
      // Data remaining keep shifting
      if(int_dwen_pend) begin
        int_merge_pkt_out = int_nop_merge_pkt;
      // No Data remaining
      end else
        int_merge_pkt_out = '0;
    end
  end
end : fc_merge_proc

// 7 TLP's accumulated halt to prevent too many TLP's per flit half
logic [P_NW - 1 : 0]  merge_halt_sot_out;
logic                 fm_sot_in;
logic [P_NW - 1 : 0]  fm_sot_out;

// Mask the inputs in non-flit mode this tracker is only used in flit mode
assign fm_sot_in = flit_mode_en ? pkt_in_chk.sot : '0;
assign fm_sot_out = flit_mode_en ? int_fc_merge_fm_pkt_out.sot[P_NW - 1 : 0] : '0;
assign merge_halt_sot_out = {P_NW{halt_in}};


// Count SOT In Decrement on Sot Out
xtlh_tlp_counter
 #(
  .P_NW_IN              (1),
  .P_NW_OUT             (P_NW),
  .P_OUTSTANDING_CNT_WD (P_MERGE_MAX_CNT_WD)
) u_fc_tlp_merge_counter(
  .core_clk             (core_clk),
  .core_rst_n           (core_rst_n),
  .flush                (1'b0),
  .sot_in               (fm_sot_in),
  .eot_out              (fm_sot_out),
  .halt_sot_in          (xtlh_fc_merge_halt_out),
  .halt_eot_out         (merge_halt_sot_out),
  .xtlh_tlp_counter_val (int_fc_merge_tlp_count)
);

assign xtlh_fc_merge_tlp_count = int_fc_merge_tlp_count;

assign int_pad_dwen = {{((P_N_SHIFT_MERGE * 8) - (P_MERGE_NW - P_NW)){1'b0}}, int_merge_pkt_out_r.dwen[P_MERGE_NW - 1 : P_NW]};
assign int_accum_pad_dwen = {{((P_N_SHIFT_MERGE * 8) - P_NW){1'b0}}, int_merge_pkt_out_r.dwen[P_NW - 1 : 0]};

always_comb begin : tlp_limit_decode_PROC
  int_max_tlp_limit = 'd1;
  if(cons_packet_limit == 2'b00)
    int_max_tlp_limit = 'd1;
  else if(cons_packet_limit == 2'b01)
    int_max_tlp_limit = 'd2;
  else if(cons_packet_limit == 2'b10)
    int_max_tlp_limit = 'd4;
  else
    int_max_tlp_limit = 'd7;
end : tlp_limit_decode_PROC

generate
  for(genvar j = 0; j < P_N_SHIFT_MERGE; j++) begin : g_shift_merge
    xtlh_tlp_shift_merge
     #(
      .P_START_INDEX  (j * 8)
    ) u_pkt_0_sm (
      .intf           (intf),
      .accum_dwen     (int_pad_dwen[j*8 +: 8]),
      .accum_data     (int_merge_pkt_out_r),
      .pkt_in         (pkt_in_chk),
      .tlp_len        (int_tlp_len),
      .merge_pkt_out  (int_p0_sm_pkt[j])
    );
  end
endgenerate

assign int_en_accum_tlp = !(|int_merge_pkt_out_r.dwen[P_MERGE_NW - 1 : P_NW]);

generate
  for(genvar j = 0; j < P_N_SHIFT_MERGE; j++) begin : g_accum_shift_merge
    xtlh_tlp_accum
     #(
      .P_START_INDEX  (j * 8)
    ) u_pkt_0_accum (
      .intf           (intf),
      .enable         (int_en_accum_tlp),
      .accum_dwen     (int_accum_pad_dwen[j*8 +: 8]),
      .accum_data     (int_merge_pkt_out_r),
      .pkt_in         (pkt_in_chk),
      .tlp_len        (int_tlp_len),
      .merge_pkt_out  (int_p0_accum_pkt[j])
    );
  end
endgenerate

xtlh_tlp_merge
 u_pkt_0_m (
  .intf           (intf),
  .pkt_in         (pkt_in_chk),
  .tlp_len        (int_tlp_len),
  .merge_pkt_out  (int_p0_m_pkt)
);

// Shift out data and pad with NOP's
xtlh_tlp_shift
 u_nop_s (
  .shift_en       (int_dwen_accum),
  .accum_data     (int_merge_pkt_out_r),
  .merge_pkt_out  (int_nop_merge_pkt)
);


always_comb begin : p0_sel_PROC
  int_sm_p0_sel_r = '0;
  for(int i = 0; i < P_N_SHIFT_MERGE; i++)
    int_sm_p0_sel_r[i]= |int_pad_dwen[(i*8) + 8 - 1 -: 8];
end : p0_sel_PROC

always_comb begin : p0_pkt_mux_PROC
  int_p0_found = find_last(int_sm_p0_sel_r);
  int_p0_merge_pkt_mux = int_p0_m_pkt;
  for(int i = 0; i < P_N_SHIFT_MERGE; i++) begin
    if(int_p0_found[i])
      int_p0_merge_pkt_mux = int_p0_sm_pkt[i];
  end
end : p0_pkt_mux_PROC

always_comb begin : p0_accum_sel_PROC
  int_accum_p0_sel_r = '0;
  for(int i = 0; i < P_N_SHIFT_MERGE; i++)
    int_accum_p0_sel_r[i]= |int_accum_pad_dwen[(i*8) + 8 - 1 -: 8];
end : p0_accum_sel_PROC

always_comb begin : p0_accum_pkt_mux_PROC
  int_accum_p0_found = find_last(int_accum_p0_sel_r);
  int_accum_p0_merge_pkt_mux = int_p0_m_pkt;
  for(int i = 0; i < P_N_SHIFT_MERGE; i++) begin
    if(int_accum_p0_found[i])
      int_accum_p0_merge_pkt_mux = int_p0_accum_pkt[i];
  end
end : p0_accum_pkt_mux_PROC

// -----------------------------------------------------------------------------
// Functions
// -----------------------------------------------------------------------------
// Return onehot encoding of last bit set in the vector
function automatic logic [P_N_SHIFT_MERGE - 1 : 0] find_last(
  input [P_N_SHIFT_MERGE - 1 : 0]  sig_in 
);
  logic found_last;
  find_last = '0;
  found_last = 0;
  if(sig_in[P_N_SHIFT_MERGE - 1])
    find_last[P_N_SHIFT_MERGE - 1] = 1'b1;
  else if(sig_in == 1)
    find_last[0] = 1'b1;
  else begin
    for(int i = P_N_SHIFT_MERGE - 2; i > 0; i--) begin
      if(!found_last && (sig_in[i] == 1)) begin
        find_last[i] = 1'b1;
        found_last = 1'b1;
      end
    end
  end
  return find_last;
endfunction



endmodule
