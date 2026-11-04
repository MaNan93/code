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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_cxl_io_flit_pid.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit Data Link Layer Hander
// --- This module handles 128b, 256b and 512b datapath widths. 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module xdlh_cxl_io_flit_pid
#(
    parameter   NW          = `CX_NW,   // Number of 32-bit dwords handled by the datapath each clock. This module supports 4, 8 and 16 
    parameter   DW          = (32*NW),  // Width of datapath in bits.
    parameter   TP          = `TP       // Clock to Q delay (simulator insurance)
) 
                           (
// Inputs ------------------------------------------------------------------------------
    input                                  core_clk,                      // Core clock
    input                                  core_rst_n,                    // Core reset
    input                                  cxl_mode_enable,               // CXL Mode Enable
    input                                  xdlh_xplh_stall_req,           // XDLH to XPLH IF - Stall Request
    input                                  xdlh_xplh_pkt_pending,         // XDLH to XPLH IF - Packet Pending
    input                                  xdlh_xplh_dv,                  // XDLH to XPLH IF - Data Valid
    input          [DW-1:0]                xdlh_xplh_data,                // XDLH to XPLH IF - Data
    input          [NW-1:0]                xdlh_xplh_stp,                 // XDLH to XPLH IF - STP Token
    input          [NW-1:0]                xdlh_xplh_sdp,                 // XDLH to XPLH IF - SDP Token
    input          [NW-1:0]                xdlh_xplh_eot,                 // XDLH to XPLH IF - EOT Token
    input          [NW-1:0]                xdlh_xplh_eod,                 // XDLH to XPLH IF - EOD Token
    input                                  xplh_arbmux_xdlh_halt,         // XPLH ARB/MUX to XDLH IF - Halt
// Outputs -----------------------------------------------------------------------------
    output  logic                          xdlh_xplh_stall_ack,           // XDLH to XPLH IF - Stall Acknowledge
    output  logic                          xdlh_xplh_arbmux_force_io_gnt, // Force ARB/MUX Arbiter to CXL.io to transmit generated CXL.io flit with IDLE tokens
    output  logic                          xdlh_xplh_arbmux_dv,           // XDLH to XPLH ARB/MUX IF - Data Valid
    output  logic  [DW-1:0]                xdlh_xplh_arbmux_data,         // XDLH to XPLH ARB/MUX IF - Data extended with 16-bit for PID
    output  logic  [NW-1:0]                xdlh_xplh_arbmux_stp,          // XDLH to XPLH ARB/MUX IF - STP Token
    output  logic  [NW-1:0]                xdlh_xplh_arbmux_sdp,          // XDLH to XPLH ARB/MUX IF - SDP Token
    output  logic  [NW-1:0]                xdlh_xplh_arbmux_eot,          // XDLH to XPLH ARB/MUX IF - EOT Token
    output  logic  [NW-1:0]                xdlh_xplh_arbmux_eod,          // XDLH to XPLH ARB/MUX IF - EOD Token
    output  logic                          xplh_xdlh_halt                 // XDLH to XPLH IF - Halt

);

localparam DW_RATIO              = `CX_CXL_20_NW / `CX_NW;
localparam DW_RATIO_LOG2         = $clog2(DW_RATIO);
localparam NFM_NW                = (NW>16) ? 16 : NW;

logic                  int_xdlh_xplh_stall_req ; // Internal XDLH Stall Request
logic                  int_xdlh_xplh_halt      ; // Internal XDLH Halt
logic                  idle_io_flit_dv_nxt     ; // IDLE flit valid - next state
logic                  idle_io_flit_dv         ; // IDLE flit valid


// -------------------------------------------------------------------------------------
// Generate a CXL.io flit containing PCIe IDLE tokens if there are no flits available for
// the transmission and during the last CXL.io flit, a TLP ended on the flit boundary
// -------------------------------------------------------------------------------------
assign xdlh_xplh_arbmux_force_io_gnt = idle_io_flit_dv;

always_comb begin
    if (!int_xdlh_xplh_halt)
        idle_io_flit_dv_nxt = xdlh_xplh_arbmux_dv && xdlh_xplh_arbmux_eot[NFM_NW-1];
    else
        idle_io_flit_dv_nxt = idle_io_flit_dv;
end

always @(posedge core_clk or negedge core_rst_n) begin
    if ( !core_rst_n ) begin
        idle_io_flit_dv <= #TP 1'b0;
    end else begin
        idle_io_flit_dv <= #TP idle_io_flit_dv_nxt;
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Stall Request/Acvknowledge Interface
// -------------------------------------------------------------------------------------
logic  xdlh_xplh_stall_ack_nxt;

// Assert internal stall request when stall request is acknowledge in CXL mode
assign int_xdlh_xplh_stall_req = cxl_mode_enable ? xdlh_xplh_stall_ack : 1'b1;
// In 68B Flit mode halt XDLH interface when either CXL.io datapath is stalled or halted by ARB/MUX
assign int_xdlh_xplh_halt      = int_xdlh_xplh_stall_req ? 1'b1 : xplh_arbmux_xdlh_halt;

always_comb begin
    // If stall_req is asserted and there are no pending packets and valid data on XDLH interface then assert stall_ack
    if (xdlh_xplh_stall_req && !xdlh_xplh_pkt_pending && !xdlh_xplh_arbmux_dv)
        xdlh_xplh_stall_ack_nxt = 1'b1;
    else if (!xdlh_xplh_stall_req)
        xdlh_xplh_stall_ack_nxt = 1'b0;
    else
        xdlh_xplh_stall_ack_nxt = xdlh_xplh_stall_ack;
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

// -------------------------------------------------------------------------------------
// Mux between IDLE and CXL.io flit on XDLH to XPLH ARB/MUX Interface
// -------------------------------------------------------------------------------------
always_comb begin
    // If stall request is acknowledged then stall XDLH to ARB/MUX interface.
    // Gate all signals on ARB/MUX interface and halt XDLH interface.
    if (int_xdlh_xplh_stall_req) begin
        xplh_xdlh_halt         = 1'b1;
        xdlh_xplh_arbmux_dv    = 1'b0;
        xdlh_xplh_arbmux_data  = '0;
        xdlh_xplh_arbmux_stp   = '0;
        xdlh_xplh_arbmux_sdp   = '0;
        xdlh_xplh_arbmux_eot   = '0;
        xdlh_xplh_arbmux_eod   = '0;
    end
    // Generate CXL.io flit with IDLE tokens
    else if (idle_io_flit_dv) begin
        xplh_xdlh_halt         = 1'b1;
        xdlh_xplh_arbmux_dv    = 1'b1;
        xdlh_xplh_arbmux_data  = '0;
        xdlh_xplh_arbmux_stp   = '0;
        xdlh_xplh_arbmux_sdp   = '0;
        xdlh_xplh_arbmux_eot   = '0;
        xdlh_xplh_arbmux_eod   = '0;
    end
    // Propagate XDLH interface to ARB/MUX inputs
    else begin
        xplh_xdlh_halt         = xplh_arbmux_xdlh_halt;
        xdlh_xplh_arbmux_dv    = xdlh_xplh_dv;
        xdlh_xplh_arbmux_data  = xdlh_xplh_data;
        xdlh_xplh_arbmux_stp   = xdlh_xplh_stp;
        xdlh_xplh_arbmux_sdp   = xdlh_xplh_sdp;
        xdlh_xplh_arbmux_eot   = xdlh_xplh_eot ^ xdlh_xplh_eod;
        xdlh_xplh_arbmux_eod   = xdlh_xplh_eod;
    end
end
// -------------------------------------------------------------------------------------

endmodule

