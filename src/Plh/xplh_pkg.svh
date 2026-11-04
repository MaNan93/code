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

// -----------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Author: lnicola $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_pkg.svh#5 $
// -----------------------------------------------------------------------------

`ifndef __GUARD__XPLH_PKG__SVH__
`define __GUARD__XPLH_PKG__SVH__

// -----------------------------------------------------------------------------
// --- Package Description: Package containing common variables and functions for xplh 
// -----------------------------------------------------------------------------
`include "products/cx_pl_pkg.svh"
package xplh_pkg;

  import cx_pl_pkg::P_RBUF_DEPTH;
  import cx_pl_pkg::P_NW;
  import cx_pl_pkg::replay_cmd_t;
  import cx_pl_pkg::dllp_type_e;
  import cx_pl_pkg::P_FLIT_DW_CNT;
  import cx_pl_pkg::x_minus_y_mod_1023;
  import cx_pl_pkg::P_DW;

  // -----------------------------------------------------------------------------
  // Flit Mode Retry Related Parameters 
  // -----------------------------------------------------------------------------
  // Maximum sequence number
  localparam  P_MAX_SEQNUM                    = 1023;
  // Sequence number width
  localparam  P_TX_SEQNUM_WD                  = $clog2(P_MAX_SEQNUM);
  // Explicit Sequence Counter Width
  localparam  P_EXPL_CNT_WD                   = 2;
  // Maximum unacknowledged Flits
  localparam  P_MAX_UNACKNOWLEDGED_FLITS      = `CX_MAX_UNACKNOWLEDGED_FLITS;
  localparam  P_NB                            = `CX_NB;
  // NAK Ignore Parameters
  localparam  P_GEN6_X8_NAK_IGNORE_VALUE      = `CX_GEN6_X8_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN5_X8_NAK_IGNORE_VALUE      = `CX_GEN5_X8_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN4_X8_NAK_IGNORE_VALUE      = `CX_GEN4_X8_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN3_X8_NAK_IGNORE_VALUE      = `CX_GEN3_X8_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN2_X8_NAK_IGNORE_VALUE      = `CX_GEN2_X8_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN1_X8_NAK_IGNORE_VALUE      = `CX_GEN1_X8_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN6_X4_NAK_IGNORE_VALUE      = `CX_GEN6_X4_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN5_X4_NAK_IGNORE_VALUE      = `CX_GEN5_X4_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN4_X4_NAK_IGNORE_VALUE      = `CX_GEN4_X4_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN3_X4_NAK_IGNORE_VALUE      = `CX_GEN3_X4_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN2_X4_NAK_IGNORE_VALUE      = `CX_GEN2_X4_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN1_X4_NAK_IGNORE_VALUE      = `CX_GEN1_X4_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN6_X2_NAK_IGNORE_VALUE      = `CX_GEN6_X2_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN5_X2_NAK_IGNORE_VALUE      = `CX_GEN5_X2_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN4_X2_NAK_IGNORE_VALUE      = `CX_GEN4_X2_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN3_X2_NAK_IGNORE_VALUE      = `CX_GEN3_X2_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN2_X2_NAK_IGNORE_VALUE      = `CX_GEN2_X2_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN1_X2_NAK_IGNORE_VALUE      = `CX_GEN1_X2_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN6_X1_NAK_IGNORE_VALUE      = `CX_GEN6_X1_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN5_X1_NAK_IGNORE_VALUE      = `CX_GEN5_X1_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN4_X1_NAK_IGNORE_VALUE      = `CX_GEN4_X1_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN3_X1_NAK_IGNORE_VALUE      = `CX_GEN3_X1_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN2_X1_NAK_IGNORE_VALUE      = `CX_GEN2_X1_NAK_IGNORE_VALUE / P_NB;
  localparam  P_GEN1_X1_NAK_IGNORE_VALUE      = `CX_GEN1_X1_NAK_IGNORE_VALUE / P_NB;
  localparam  P_NAK_IGNORE_WD                 = 12;
  // Replay Timeout Flit Counter
  localparam  P_REPLAY_TIMER_VAL              = 1500;
  localparam  P_REPLAY_TIMER_WD               =  $clog2(P_REPLAY_TIMER_VAL);
  // Number of retry buffer entries for maximum sized TLP
  localparam  P_MAX_RBUF_ENTRIES              = `CX_RBUF_DATASIZE;
  // RBUF DEPTH LIMIT is the depth less the maximum sized TLP
  localparam  P_RBUF_DEPTH_LIMIT              = P_RBUF_DEPTH - P_MAX_RBUF_ENTRIES;
  // Round RBUF DEPTH LIMIT down to the nearest multiple of dw for a full flit
  localparam  P_RBUF_DEPTH_LIMIT_RD           = P_RBUF_DEPTH_LIMIT - (P_RBUF_DEPTH_LIMIT % P_FLIT_DW_CNT);
  // Number of Flits required for write protection overhead
  localparam  P_RBUF_FLIT_PROT_NUM            = (P_RBUF_DEPTH / P_FLIT_DW_CNT) - (P_RBUF_DEPTH_LIMIT_RD / P_FLIT_DW_CNT);
  // Retry buffer flit limit as a number of Flits - 1
  // Max Unacknowledge Flits - the overhead for protection we need 1 extra space to allow for the fact that the write pointer is rolled back after end of NOP Flit
  localparam  P_RBUF_FLIT_LIMIT               = P_MAX_UNACKNOWLEDGED_FLITS - P_RBUF_FLIT_PROT_NUM - 2;

  // Retry Request Struct
  typedef struct packed {
    replay_cmd_t                    replay_cmd;         // ACK/NAK Replay Command
    logic                           replay_scheduled;   // Replay Scheduled Indication
  } retry_req_struct;

  // Retry Buffer Payload Flit Tracker used to de-allocate space in the retry buffer
  typedef struct packed {
    logic [P_TX_SEQNUM_WD - 1 : 0]  count;        // Number of payload flits sent since the last ACK/NAK
    logic                           valid;        // Payload count valid flag
    replay_cmd_t                    replay_cmd;   // Whether the counter updated due to Ack or Nak
  } payload_cnt_struct;

  typedef enum logic {
    TX_NOP = 1'b0,
    TX_PAYLOAD = 1'b1
  } nop_flag_e;

  typedef enum logic [1:0] {
    IDLE_OR_NOP = 2'b00, // IDLE, Physical Layer NOP, or CXL.io NOP
    PAYLOAD     = 2'b01, // PCIe PAYLOAD or CXL.io
    CXL_CM      = 2'b10, // CXL.cachemem or CXL.cachemem NOP flit
    CXL_ALMP    = 2'b11  // ALMP
  } flit_usage_e;

  typedef enum logic {
    DLLP = 1'b0,
    OPT_UPD_OR_FM = 1'b1
  } dllp_pyld_type_e;
  
  // XPLH Control State
  typedef enum {
    RESET,            // Reset
    FLIT_SEQ_NUM_HS,  // Sequence Number handshake (send NOP's Send Replay Command 00)
    FLUSH,            // Flush the data path
    NORMAL            // Send Payload Flits (or NOP if nothing available)
  } xplh_state_e;

// Description (N - ACKD_FLIT_SEQ_NUM) mod 1023 > 0
function automatic logic check_ackd_seqnum(
  input [P_TX_SEQNUM_WD - 1 : 0]  rx_seqnum,
  input [P_TX_SEQNUM_WD - 1 : 0]  ackd_seqnum
);
  logic [P_TX_SEQNUM_WD - 1 : 0] rule;

  rule = x_minus_y_mod_1023(rx_seqnum, ackd_seqnum);
  
  if(rule > 0)
    check_ackd_seqnum = 1'b1;
  else
    check_ackd_seqnum = 1'b0;

  return check_ackd_seqnum;
endfunction

// Subtract 1 from the sequence number
function automatic logic [P_TX_SEQNUM_WD - 1 : 0] seqnum_minus_1(
  input [P_TX_SEQNUM_WD - 1 : 0]  seqnum
);
  logic [P_TX_SEQNUM_WD - 1 : 0] eq_one;
  eq_one = {{(P_TX_SEQNUM_WD - 1){1'b0}}, 1'b1};
  // 1 - 1 = 1023
  if((seqnum == eq_one) || (seqnum == '0))
    seqnum_minus_1 = '1;
  else
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. This code is using modulo arithmetic. So, disable SpyGlass from reporting this warning.
    seqnum_minus_1 = seqnum - 1'b1;
// spyglass enable_block W164a
  return seqnum_minus_1;
endfunction
  
// Add 1 to the sequence number
function automatic logic [P_TX_SEQNUM_WD - 1 : 0] seqnum_plus_1(
  input [P_TX_SEQNUM_WD - 1 : 0]  seqnum
);
  logic [P_TX_SEQNUM_WD - 1 : 0] eq_one;
  eq_one = {{(P_TX_SEQNUM_WD - 1){1'b0}}, 1'b1};
  // 1023 + 1 = 1
  if(seqnum == '1)
    seqnum_plus_1 = eq_one;
  else
    seqnum_plus_1 = seqnum + 1'b1;
  return seqnum_plus_1;
endfunction

function automatic logic [P_DW-1:0] inject_crc_error (
  input            crc_error,
  input [P_DW-1:0] data_in,
  input            ehf,
  input            eof
);
  logic [P_DW-1:0] data_out;

  data_out = data_in;

  if (crc_error) begin
    if (ehf) begin
      if (!eof)
        // corrupt 6B CRC for even half flit
        data_out[P_DW-(8*6)  +: (8*6)] = {48{1'b1}}; 
      else
        // corrupt 6B CRC for odd half flit, insert in same position as standard flit mode, the CRC bytes will be moved to correct position after ECC calculation
        data_out[P_DW-(8*12) +: (8*6)] = {48{1'b1}};
    end
    else if (eof) begin
      data_out[P_DW-(8*14) +: (8*8)] = {64{1'b1}};
    end
  end
  return data_out;
endfunction : inject_crc_error

endpackage // xplh_pkg

`endif // __GUARD__XPLH_PKG__SVH__
