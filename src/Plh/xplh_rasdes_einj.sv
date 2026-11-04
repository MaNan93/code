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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_rasdes_einj.sv#2 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH RASDES Control
//
// Description: RASDES Error Injection.
//
// -------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xplh_rasdes_einj
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::P_TX_SEQNUM_WD;
  import  cx_pl_pkg::P_DLP0_END;
  import  cx_pl_pkg::P_DLP1_END;
  import  cx_pl_pkg::replay_cmd_t;
  import  cx_pl_pkg::P_REPLAY_CMD_END;
  import  cx_pl_pkg::REPLAY_00;
  import  cx_pl_pkg::ACK;
  import  cx_pl_pkg::NAK_10;
  import  cx_pl_pkg::NAK_11;
#(
  parameter TP = `TP
) 
                         (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                   core_clk,
  input                   core_rst_n,
  // -------------------------------------------------------------------------------------
  // RASDES Error Mode Signals
  // -------------------------------------------------------------------------------------
  input                   cdm_ras_des_einj1_enable,        // RASDES Error Injection Enable
  input                   cdm_ras_des_einj1_seq_type,      // RASDES Error Injection Type
  input  [12: 0]          cdm_ras_des_einj1_bad_seq,       // RASDES Added Bad Sequence
  input  [7 : 0]          cdm_ras_des_einj1_count,         // RASDES Error Injection Count
  // -------------------------------------------------------------------------------------
  // XPLH Interface
  // -------------------------------------------------------------------------------------
  input                   halt_in,                              // Halt from lower layer
  output  [1:0]           xplh_ras_des_einj1_exp_sequm_evt,     // Pluse to indicate error injection event occurred in explict sequence number
  output                  xplh_ras_des_einj1_ack_nak_sequm_evt, // Pluse to indicate error injection event occurred in ACK/NAK sequence number
  // -------------------------------------------------------------------------------------
  // Flit Interfaces
  // -------------------------------------------------------------------------------------
  input   tx_flit_struct  flit_in,                          // Input Flit
  output  tx_flit_struct  xplh_ras_des_einj1_flit_out       // Output Flit with error injected
);

typedef enum {
  IDLE,     
  EINJ_EN,   
  EINJ_COUNT,  
  WAIT_DONE     
} rasdes_state;

rasdes_state state_r,next_state;

logic [P_TX_SEQNUM_WD-1:0]  seqnum;
logic [P_TX_SEQNUM_WD-1:0]  int_seqnum_r;
logic                       valid_seqnum;
logic [7:0]                 dlp0;
logic [7:0]                 dlp1;
replay_cmd_t                int_replay_cmd;
logic [P_TX_SEQNUM_WD-1:0]  seqnum_einj;
logic [P_TX_SEQNUM_WD-1:0]  seqnum_einj_r;
logic [7:0]                 int_einj_count;
logic [1:0]                 xplh_ras_des_einj1_exp_sequm_evt_int;
logic                       xplh_ras_des_einj1_ack_nak_sequm_evt_int;
logic                       xplh_ras_des_einj1_en;

// Extract the sequence number from the transmitted Flit
assign dlp0 = flit_in.data[P_DLP0_END -: 8];
assign dlp1 = flit_in.data[P_DLP1_END -: 8];
assign seqnum = {dlp0[1:0], dlp1};

// Extract the replay command from the transmitted Flit
assign int_replay_cmd = replay_cmd_t'(flit_in.data[P_REPLAY_CMD_END : P_REPLAY_CMD_END - 1]);

// Current state logic
always_ff @(posedge core_clk or negedge core_rst_n) begin : state_sync_PROC
  if(!core_rst_n)
    state_r <= #TP IDLE;
  else
    state_r <= #TP next_state;
end : state_sync_PROC

// Next state logic
always_comb begin : state_PROC
  next_state = state_r;

  case(state_r)
    // Inject error in the FLits till the enable is de-asserted
    EINJ_EN : begin
      if (!cdm_ras_des_einj1_enable) 
        next_state = IDLE;
    end

   // Inject error in the flits with the requested count
    EINJ_COUNT : begin
      // If enable is de-asserted in middle of injection
      if (!cdm_ras_des_einj1_enable && (cdm_ras_des_einj1_count != 0)) 
        next_state = IDLE;
      else if (cdm_ras_des_einj1_count == int_einj_count)
        next_state = WAIT_DONE;
      else
        next_state = EINJ_COUNT;
    end

   // Check of all errors are Injected
    WAIT_DONE: begin
      // If enable is de-asserted in middle of injection
      if (!cdm_ras_des_einj1_enable && (cdm_ras_des_einj1_count != 0)) 
        next_state = IDLE;
      else if(cdm_ras_des_einj1_count == 0) 
        next_state = IDLE;
      else
        next_state = EINJ_COUNT;
    end

    default : begin // IDLE
      if (cdm_ras_des_einj1_enable) begin
        if (cdm_ras_des_einj1_count == 0)
         next_state = EINJ_EN;
        else
         next_state = EINJ_COUNT;
      end
    end
  endcase
end : state_PROC

// Inject error in Explict Flit
assign xplh_ras_des_einj1_exp_sequm_evt_int = (!cdm_ras_des_einj1_seq_type && (int_replay_cmd==REPLAY_00))? 2'b01 : 2'b00;
// Inject error in ACK/NAK Flit
assign xplh_ras_des_einj1_ack_nak_sequm_evt_int = (cdm_ras_des_einj1_seq_type && (int_replay_cmd inside {ACK, NAK_10, NAK_11}))? 1'b1 : 1'b0;

//If the data path width is greater than 128-bit, the seqnum can be detected when eof=2'b11
//If the data path width is 128-bit, the seqnum can be detected when eof=2'b01
assign valid_seqnum = !halt_in && flit_in.eof[0] && cdm_ras_des_einj1_enable;

// Extract the seqnum when the flit is completed 
assign int_seqnum_r = (valid_seqnum)? seqnum : '0;

// Add/Subtract the bad seqnum from the original one
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Sequence counters are intended to
// wrap without preseveration of carry/borrow
assign seqnum_einj = int_seqnum_r + cdm_ras_des_einj1_bad_seq[9:0];
// spyglass enable_block W164a

// Insert the new sequence number in the flit
always_comb begin : flit_out_einj_PROC
     xplh_ras_des_einj1_flit_out =  flit_in;
   if(xplh_ras_des_einj1_en) begin
     xplh_ras_des_einj1_flit_out.data[P_DLP0_END-6 : P_DLP0_END-7]   = seqnum_einj[9:8];
     xplh_ras_des_einj1_flit_out.data[P_DLP1_END  -: 8]              = seqnum_einj[7:0];
   end else
     xplh_ras_des_einj1_flit_out =  flit_in;
end : flit_out_einj_PROC

// Acknowledge the CDM that the error Is Injected In Explicit Flit.
assign xplh_ras_des_einj1_exp_sequm_evt = ((xplh_ras_des_einj1_exp_sequm_evt_int==2'b01) && xplh_ras_des_einj1_en)? 2'b01:2'b00;
// Acknowledge the CDM that the error Is Injected In ACK/NAK Flit.
assign xplh_ras_des_einj1_ack_nak_sequm_evt = (xplh_ras_des_einj1_ack_nak_sequm_evt_int && xplh_ras_des_einj1_en)? 1'b1:1'b0;

// Selection to pass the Injected/Normal Flit.
assign xplh_ras_des_einj1_en = (((state_r== EINJ_COUNT) || (state_r== EINJ_EN) ) && ((xplh_ras_des_einj1_exp_sequm_evt_int==2'b01) || xplh_ras_des_einj1_ack_nak_sequm_evt_int) && valid_seqnum)? 1'b1 : 1'b0;

// Internal Counter
always_ff @(posedge core_clk or negedge core_rst_n) begin : Internal_count_PROC
  if(!core_rst_n)
   int_einj_count <= #TP '0;
  else if ((next_state == EINJ_COUNT) && (state_r != EINJ_COUNT))
   int_einj_count <= #TP int_einj_count-1;
  else if (state_r == IDLE)
   int_einj_count <= #TP cdm_ras_des_einj1_count;
end : Internal_count_PROC

`ifndef SYNTHESIS
`endif // SYNTHESIS
endmodule
