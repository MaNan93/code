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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_spif_datapath.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description: XDLH Non Flit Mode SPIF Datapath
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module xdlh_spif_datapath
#(
    parameter   NW          = `CX_NW,   // Number of 32-bit dwords handled by the datapath each clock. This module supports 4, 8 and 16 
    parameter   DW          = (32*NW),  // Width of datapath in bits.
    parameter   TP          = `TP       // Clock to Q delay (simulator insurance)
) (
// Inputs ------------------------------------------------------------------------------
    input                           core_clk,                   // Core Clock
    input                           core_rst_n,                 // Core Reset
    input                           xdlh_xplh_spif_enable,      // Enable SPIF Interface on XDLH to XPLH interface
    input                           xdlh_xplh_pcie_enable,      // Enable PCIe mode
    input                           xdlh_xplh_stall_req,        // XDLH to XPLH IF - Stall Request
    input                           xdlh_xplh_dv,               // XDLH to XPLH Interface - Data Valid
    input         [DW-1:0]          xdlh_xplh_data_in,          // XDLH to XPLH Interface - Data for transmission.
    input         [NW-1:0]          xdlh_xplh_sdp,              // Start of DLLP
    input         [NW-1:0]          xdlh_xplh_stp,              // Start of TLP
    input         [NW-1:0]          xdlh_xplh_eot,              // End of TLP
    input         [NW-1:0]          xdlh_xplh_dllp_end,         // End of DLLP
    input                           xdlh_xplh_pkt_pending,      // TLP Pending indication
    input                           xplh_xdlh_halt,             // XPLH to XDLH IF - Halt
// Outputs -----------------------------------------------------------------------------
    output  logic                   xdlh_xplh_stall_ack,        // XDLH to XPLH IF - Stall Acknowledge
    output  logic                   xdlh_xplh_halt_out,         // XDLH to XPLH Halt
    output  logic                   xdlh_xplh_dv_out,           // XDLH to XPLH Data Valid
    output  logic [DW-1:0]          xdlh_xplh_data_out,         // XDLH to XPLH Data 
    output  logic [NW-1:0]          xdlh_xplh_dlp_start,        // Start of DLLP
    output  logic [NW-1:0]          xdlh_xplh_dlp_end,          // End of DLLP
    output  logic [NW-1:0]          xdlh_xplh_tlp_start,        // Start of TLP
    output  logic [NW-1:0]          xdlh_xplh_tlp_end
);

// Internal declarations
logic xdlh_xplh_stall_ack_nxt;
logic int_xdlh_xplh_stall_req;

// Assert internal stall request when stall request is acknowledge in PCIe mode
assign int_xdlh_xplh_stall_req = (xdlh_xplh_spif_enable && xdlh_xplh_pcie_enable) ? xdlh_xplh_stall_ack : 1'b1;

// -------------------------------------------------------------------------------------
// XDLH to XPLH Interface output mux
// -------------------------------------------------------------------------------------
always_comb begin
  // If stall request is acknowledged then stall XDLH to XPLH interface.
  // Gate all signals on XPLH interface and halt XDLH interface.
  if (int_xdlh_xplh_stall_req) begin
    xdlh_xplh_halt_out  = 1'b1;
    xdlh_xplh_dv_out    = '0;
    xdlh_xplh_data_out  = '0;
    xdlh_xplh_dlp_start = '0;
    xdlh_xplh_dlp_end   = '0;
    xdlh_xplh_tlp_start = '0;
    xdlh_xplh_tlp_end   = '0;
  // Propagate XDLH interface to XPLH
  end else begin
    xdlh_xplh_halt_out  = xplh_xdlh_halt;
    xdlh_xplh_dv_out    = xdlh_xplh_dv;
    xdlh_xplh_data_out  = xdlh_xplh_data_in;
    xdlh_xplh_dlp_start = xdlh_xplh_sdp;
    xdlh_xplh_dlp_end   = xdlh_xplh_dllp_end;
    xdlh_xplh_tlp_start = xdlh_xplh_stp;
    xdlh_xplh_tlp_end   = xdlh_xplh_eot ^ xdlh_xplh_dllp_end;
  end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Stall Request/Acvknowledge Interface
// -------------------------------------------------------------------------------------
always_comb begin
    if (xdlh_xplh_stall_req && !xdlh_xplh_dv && !xdlh_xplh_pkt_pending)
        xdlh_xplh_stall_ack_nxt = 1'b1;
    else if (!xdlh_xplh_stall_req)
        xdlh_xplh_stall_ack_nxt = 1'b0;
    else begin
        xdlh_xplh_stall_ack_nxt = xdlh_xplh_stall_ack;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        xdlh_xplh_stall_ack <= # TP '0;
    end
    else begin
        xdlh_xplh_stall_ack <= # TP xdlh_xplh_stall_ack_nxt;
    end
end
// -------------------------------------------------------------------------------------

endmodule // xdlh_spif_datapath

