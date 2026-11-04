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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_tlp_tracker.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module tracks TLP's through the XDLH and generates a pending flag.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"

 
 module xdlh_tlp_tracker
  import spif_pkg::SPIF_NWORDS;
  // Parameters
  #(
    parameter TP      = `TP,
    parameter NW      = `CX_NW,
    parameter SOT_WD  = 1
  ) (
    // Inputs
    input                       core_clk,
    input                       core_rst_n,
    input [(SOT_WD - 1) : 0]    xtlh_xdlh_sot,          // Start of TLP indication to XDLH
    input                       xdlh_xtlh_halt,         // XDLH halt to the XTLH
    input [(SOT_WD - 1) : 0]    rbuf_xmt_sot,           // Start of TLP indication from retrybuffer
    input                       rbuf_halt,              // Halt of retrybuffer
    input                       clear_pending,          // flag to clear the pending
    input                       xdlh_in_reply,          // retry buffer FSM replay state
    input                       xdlh_not_expecting_ack, // Ack/Nak DLLP pending
    input                       lp_valid,               // SPIF Data Valid
    input                       lp_irdy,                // Link Layer Ready Indication
    input [SPIF_NWORDS - 1 : 0] lp_tlp_end,             // TLP End Indication
    input                       pl_trdy,                // Packet Layer Ready Indication
    // Outputs
    output  logic               xdlh_tlp_pending,       // XDLH TLP pending
    output  logic               xdlh_retry_pending      // XDLH retry pending indication 
);

localparam XDLH_TLP_REGOUT  = `CX_XDLH_TLP_REGOUT;
localparam XDLH_PKT_PENDING = `XDLH_PKT_PENDING_REG;
localparam CRC_LATENCY_XDLH = `CX_CRC_LATENCY_XDLH;
localparam RASDP_PIPE_DELAY = `CX_RASDP_XDLH_PIPE_EN;
localparam CXL_ENABLE       = 0 +2 ; // 68B: merge&shift + Idle flit insertion when TLP ended at flit_boundary 
localparam EOT_CNT_WD       = ((NW==16) ? 3 : ((NW>=4) ? 2 : 1));
localparam CNT_WD = (CRC_LATENCY_XDLH + RASDP_PIPE_DELAY + CXL_ENABLE >= 2) ? 4 : 3;
//
logic [(EOT_CNT_WD - 1) : 0]  int_eot_cnt;
logic [CNT_WD : 0]            int_tlp_cnt_b;
logic [CNT_WD : 0]            int_tlp_cnt_r;
logic int_sot_req;
logic int_rbuf_req;

// Track the number of TLP's output from Layer2
// If an EOT is detected and it is not part of DLLP increment the EOT counter
always_comb begin : eot_cnt_PROC
  integer i;
  int_eot_cnt = {EOT_CNT_WD{1'b0}};
  for(i = 0; i < SPIF_NWORDS; i = i + 1) begin
    if(lp_tlp_end[i] && (lp_valid && lp_irdy && pl_trdy))
      int_eot_cnt = int_eot_cnt + 1'b1;
  end
end : eot_cnt_PROC

// SOT can either come from Layer3 or from retrybuffer
assign int_rbuf_req = (|rbuf_xmt_sot) && !rbuf_halt;
// SOT from Layer3
assign int_sot_req = ((|xtlh_xdlh_sot) && !xdlh_xtlh_halt) || int_rbuf_req;

// Count the pending TLP's in Layer2.
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The TLP counter maximum value is constrained by the datapath so by design the counter cannot overflow.
always_comb begin : tx_cnt_PROC
  if(clear_pending)
    int_tlp_cnt_b = {CNT_WD{1'b0}};
  else
    int_tlp_cnt_b = int_tlp_cnt_r + int_sot_req - int_eot_cnt;
end : tx_cnt_PROC
// spyglass enable_block W164a


always_ff @(posedge core_clk or negedge core_rst_n) begin : tx_mon_PROC
  if(!core_rst_n) begin
    int_tlp_cnt_r <= #TP {CNT_WD{1'b0}};
  end else begin
    int_tlp_cnt_r <= #TP int_tlp_cnt_b;
  end
end

// The pending tracks TLP's in and out of the XDLH
assign xdlh_tlp_pending = !(int_tlp_cnt_r == {CNT_WD{1'b0}});

// The busy flag takes into account the XDLH retry buffer FSM state since
// during the PM L1_WAIT_LAST_TLP_ACK state we need to know that the retry
// buffer is IDLE
assign xdlh_retry_pending = xdlh_tlp_pending || xdlh_in_reply || !xdlh_not_expecting_ack;


endmodule
