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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_spif_tracker.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module is a wrapper to MUX between non-spif and spif mode TLP tracking.
// Eventually when legacy non-spif interface is deprecated the sub-module xdlh_tlp_tracker
// will be instantiated directly in XDLH and this module can be removed.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"
 
 module xdlh_spif_tracker
  import spif_pkg::SPIF_NWORDS;
  // Parameters
  #(
    parameter TP      = `TP,
    parameter NW      = `CX_NW,
    parameter SOT_WD  = 1
  ) 
                           (
    // Inputs
    input                       core_clk,
    input                       core_rst_n,
    input [(SOT_WD - 1) : 0]    xtlh_xdlh_sot,          // Start of TLP indication to XDLH
    input                       xdlh_xtlh_halt,         // XDLH halt to the XTLH
    input [(NW - 1) : 0]        xplh_xmlh_eot,          // End of TLP indication to XMLH
    input                       xmlh_xplh_halt,         // XMLH halt to the XDLH
    input [(NW - 1) : 0]        xdlh_xmlh_dllp,         // Position of DLLP EOT in the datapath
    input [(SOT_WD - 1) : 0]    rbuf_xmt_sot,           // Start of TLP indication from retrybuffer
    input                       rbuf_halt,              // Halt of retrybuffer
    input                       clear_pending,          // flag to clear the pending
    input                       xdlh_in_reply,          // retry buffer FSM replay state
    input                       xdlh_not_expecting_ack, // Ack/Nak DLLP pending
    input                       lp_valid,               // SPIF Data Valid
    input                       lp_irdy,                // Link Layer Ready Indication
    input [SPIF_NWORDS - 1 : 0] lp_tlp_end,             // TLP End Indication
    input                       pl_trdy,                // Packet Layer Ready Indication
    input                       spif_enable,            // SPIF mode selected
    // Outputs
    output  logic               xdlh_tlp_pending,       // XDLH TLP pending
    output  logic               xdlh_retry_pending      // XDLH retry pending indication 
);

logic int_spif_tlp_pending;
logic int_spif_retry_pending;
logic int_spif_clear_pending;
logic int_tlp_pending;
logic int_retry_pending;
logic int_clear_pending;

// SPIF Mode TLP Tracker
xdlh_tlp_tracker
 #(
    .NW (NW),
    .SOT_WD (SOT_WD)
) u_xdlh_tlp_tracker (
    .core_clk               (core_clk),
    .core_rst_n             (core_rst_n),
    .xtlh_xdlh_sot          (xtlh_xdlh_sot),
    .xdlh_xtlh_halt         (xdlh_xtlh_halt),
    .rbuf_xmt_sot           (rbuf_xmt_sot),
    .rbuf_halt              (rbuf_halt),
    .clear_pending          (int_spif_clear_pending),
    .xdlh_in_reply          (xdlh_in_reply),
    .xdlh_not_expecting_ack (xdlh_not_expecting_ack),
    .lp_valid               (lp_valid),
    .lp_irdy                (lp_irdy),
    .lp_tlp_end             (lp_tlp_end),
    .pl_trdy                (pl_trdy),
    .xdlh_tlp_pending       (int_spif_tlp_pending),
    .xdlh_retry_pending     (int_spif_retry_pending)
);

// NON-SPIF Mode TLP Tracker
xdlh_tracker

  // Parameters
  #(
    .NW     (NW),
    .SOT_WD (SOT_WD)
  ) u_xdlh_tracker (
    // Inputs
    .core_clk                 (core_clk),
    .core_rst_n               (core_rst_n),
    .xtlh_xdlh_sot            (xtlh_xdlh_sot),
    .xdlh_xtlh_halt           (xdlh_xtlh_halt),
    .xplh_xmlh_eot            (xplh_xmlh_eot),
    .xmlh_xplh_halt           (xmlh_xplh_halt),
    .xdlh_xmlh_dllp           (xdlh_xmlh_dllp),
    .rbuf_xmt_sot             (rbuf_xmt_sot),
    .rbuf_halt                (rbuf_halt),
    .clear_pending            (int_clear_pending),
    .xdlh_in_reply            (xdlh_in_reply),
    .xdlh_not_expecting_ack   (xdlh_not_expecting_ack),
    // Outputs
    .xdlh_tlp_pending         (int_tlp_pending),
    .xdlh_retry_pending       (int_retry_pending)
);

// MUX Spif/Non-Spif
always_comb begin : spif_mux_PROC
  if(spif_enable) begin
    int_spif_clear_pending = clear_pending;
    int_clear_pending = 1'b1;
    xdlh_tlp_pending = int_spif_tlp_pending;
    xdlh_retry_pending = int_spif_retry_pending;
  end else begin
    int_spif_clear_pending = 1'b1;
    int_clear_pending = clear_pending;
    xdlh_tlp_pending = int_tlp_pending;
    xdlh_retry_pending = int_retry_pending;
  end
end : spif_mux_PROC


endmodule
