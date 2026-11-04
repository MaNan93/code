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
// ---   $DateTime: 2023/04/29 12:35:01 $
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_fm_l0p_dllp_gen.sv#2 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// L0P Control 
//
// Description: This module arbitrates between the L0P DLLP's for transmission 
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"


module xdlh_fm_l0p_dllp_gen
  import cx_pl_pkg::l0p_dllp_struct;
  import cx_pl_pkg::dllp_struct;
#(
  parameter TP = `TP
)(
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                   core_clk,           // Core clock
  input                   core_rst_n,         // Active low asynchronous reset
  // -------------------------------------------------------------------------------------
  // L0P DLLP Interface
  // -------------------------------------------------------------------------------------
  input                   l0p_cfg_rsp_ack,    // L0P Response DLLP has been transmitted
  input                   l0p_cfg_req_ack,    // L0P Request DLLP has been transmitted
  input   l0p_dllp_struct l0p_cfg_req_dllp,   // L0P Config Master FSM DLLP (Request or Upconfigure)
  input   l0p_dllp_struct l0p_cfg_rsp_dllp,   // L0P Config Slave FSM DLLP Request (Ack/Nak)
  input                   smlh_in_rcvry,      // Link entered recovery
  output  dllp_struct     xdlh_l0p_dllp       // L0P DLLP
);

// Declarations
localparam integer REG_DELAY_DENOM = 1000;
localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM;
localparam NUM_CLIENTS    = 2;
localparam INDEX_WD       = $clog2(NUM_CLIENTS);
localparam OUTPUT_MODE    = 0;
localparam [NUM_CLIENTS - 1 : 0]  CFG_RESP_DLLP  = 2'b01;
localparam [NUM_CLIENTS - 1 : 0]  CFG_REQ_DLLP   = 2'b10;

logic [NUM_CLIENTS - 1 : 0] s_l0p_dllp_req;
logic [NUM_CLIENTS - 1 : 0] s_l0p_dllp_grant;
logic [NUM_CLIENTS - 1 : 0] r_arb_lock;
logic                       l0p_dllp_sent;
logic                       s_l0p_dllp_granted;
l0p_dllp_struct             s_arb_dllp;
l0p_dllp_struct             r_arb_dllp;

// L0P DLLP Requests in order of priority
// 1. L0P_Request_Ack/Nak - l0p_cfg_rsp_dllp
// 2. L0P_Request/Up_Configure_Complete - l0p_cfg_req_dllp
assign s_l0p_dllp_req = {l0p_cfg_req_dllp.valid, l0p_cfg_rsp_dllp.valid};

// L0P DLLP Arbitration Fixed Priority Arbiter
// The only contention possible is between Ack/Nak and Request
// This is resolved by giving Ack/Nak priority
DWC_pcie_ctl_bcmmod51
 #(
    .N               (NUM_CLIENTS),
    .OUTPUT_MODE     (OUTPUT_MODE),
    .INDEX_WIDTH     (INDEX_WD),
    .REG_DELAY_TIME  (REG_DELAY_TIME),
    .REG_DELAY_DENOM (REG_DELAY_DENOM)
) u_l0p_dllp_arb (
    .clk             (core_clk),
    .rst_n           (core_rst_n),
    .init_n          (1'b1),
    .mask            ({NUM_CLIENTS{1'b0}}),
    .enable          (1'b1),
    .request         (s_l0p_dllp_req),
    .lock            (r_arb_lock),
    .grant           (s_l0p_dllp_grant),
    .granted         (s_l0p_dllp_granted),
// SMD: Output port to an instance is not connected
// SJ:  These ports are not used.
// spyglass disable_block W287b
    .grant_index     (),
    .locked          (),
    .parked          ()
// spyglass enable_block W287b
);

// Select the DLLP to transmit
always_comb begin : dllp_arb_PROC
  s_arb_dllp      = '0;
  // Select which L0P DLLP to Transmit
  if(s_l0p_dllp_granted) begin
    unique case(s_l0p_dllp_grant)
      CFG_RESP_DLLP : s_arb_dllp = l0p_cfg_rsp_dllp;
      CFG_REQ_DLLP  : s_arb_dllp = l0p_cfg_req_dllp;
      default       : s_arb_dllp = '0;
    endcase
  end
end : dllp_arb_PROC

// Locked DLLP has been granted
assign l0p_dllp_sent = (l0p_cfg_req_ack || l0p_cfg_rsp_ack) ? (r_arb_lock == {l0p_cfg_req_ack, l0p_cfg_rsp_ack}) : '0;

always_ff @(posedge core_clk or negedge core_rst_n) begin : dllp_reg_PROC
  if(!core_rst_n) begin
    r_arb_dllp      <= #TP '0;
    r_arb_lock      <= #TP '0;
  end else begin
    if(s_l0p_dllp_granted && (l0p_dllp_sent || smlh_in_rcvry)) begin
      r_arb_dllp    <= #TP '0;
      r_arb_lock    <= #TP '0;
    end else if(s_l0p_dllp_granted) begin
      r_arb_dllp    <= #TP s_arb_dllp;
      r_arb_lock    <= #TP s_l0p_dllp_grant;
    end
  end
end : dllp_reg_PROC

// Pack the L0P DLLP to the generic DLLP Structure
always_comb begin : dllp_PROC
  xdlh_l0p_dllp.pyld      = {r_arb_dllp.resp_pyld, r_arb_dllp.link_width,
                            r_arb_dllp.rsvd,r_arb_dllp.priority_bit, r_arb_dllp.l0p_cmd, r_arb_dllp.link_mng_type};
  xdlh_l0p_dllp.dllp_type = r_arb_dllp.dllp_type;
  xdlh_l0p_dllp.valid     = r_arb_dllp.valid;
end : dllp_PROC

endmodule
