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
// ---    $DateTime: 2024/01/08 11:48:14 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/sdlh_fm_l0p_mux.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description: SDLH Flit Mode L0p Mux
// -----------------------------------------------------------------------------
// --- This module multiplexes between Statis and Dynamic L0p requests
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

//`define SNPS_LOCAL_OLD_L0P_CODE

module sdlh_fm_l0p_mux #(
    parameter TP = `TP
) (
    input                  core_clk,                 // Core clock
    input                  core_rst_n,               // Core reset
// ----------------------------------------------------------------------------
// Interface to PCIe Registers for Static L0p control
// ----------------------------------------------------------------------------
    input                  cfg_l0p_enable,           // L0p Enable bit in Device Control 3 Register (bit[3])
                                                     // Asserted when both Receiver L0p Supported bit is set in Device Capabilities 3 Register (bit[3])
                                                     // and Remote L0p Supported bit is set in Device Status 3 Register (bit[4]) are set to 1b
    input                  cfg_l0p_autowidth_dis,    // Hardware Autonomous Width Disable bit in the Link Control register (bit[9])
    input                  cfg_l0p_priority,         // Port Logic register bit to set L0p.Priority bit in DLLP
    input  [2:0]           cfg_l0p_linkmode,         // Target Link Width in Device Control 3 Register (bit[6:4])
    input                  cfg_l0p_linkmode_req,     // Link Width change request asserted on the write access to Device Control 3 Register
    input  [5:0]           cfg_l0p_max_link_width,   // Maximum supported Link Width
    input  [5:0]           cfg_l0p_neg_link_width,   // Negotiated Link Width
// ----------------------------------------------------------------------------
// Interface to Port Logic Control 2 Register for Dynamic L0p
// ----------------------------------------------------------------------------
    input                  cfg_pcie_l0p_disable,     // Dynamic L0p Configuration: L0p Disable
    input                  cfg_pcie_l0p_request,     // Dynamic L0p Configuration: L0p Request
    input                  cfg_pcie_l0p_priority,    // Dynamic L0p Configuration: L0p Priority
    input  [2:0]           cfg_pcie_l0p_linkmode,    // Dynamic L0p Configuration: L0p Target Link Width
// ----------------------------------------------------------------------------
// Interface to SDLH SPIF
// ----------------------------------------------------------------------------
    input                  smlh_ltssm_l0p_ready,     // Flow Control signal indicates that LogPHY is ready to accept new request
// ----------------------------------------------------------------------------
// Interface to L0p control FSM
// ----------------------------------------------------------------------------
    input                  xdlh_cdm_link_ack,        // L0p Controller: L0p Acknowledge
    input                  xdlh_cdm_link_nak,        // L0p Controller: L0p NAK
    output logic           cdm_xdlh_link_dis,        // L0p Controller: L0p Disable
    output logic           cdm_xdlh_link_req,        // L0p Controller: L0p Request
    output logic           cdm_xdlh_link_pri,        // L0p Controller: L0p Priority
    output logic [2:0]     cdm_xdlh_link_width,      // L0p Controller: L0p Target Link Width
// ----------------------------------------------------------------------------
// Application L0p Interface
// ----------------------------------------------------------------------------
    output logic           app_dynamic_l0p_enable,   // Application Interface signal indicates that Dynamic L0p is enabled
    output logic           app_dynamic_l0p_rejected  // Application Interface signal indicates that L0p request is NAK-ed
);

// L0p Mux Signals
logic         mux_cfg_l0p_dynamic_en;        // L0p Mux control signal that selects Dynamic L0p configuration interface
logic         mux_cfg_l0p_autowidth_dis;     // L0p Mux: Hardware Autonomous Width Disable
logic         mux_cfg_l0p_request;           // L0p Mux: Request
logic         mux_cfg_l0p_priority;          // L0p Mux: Priority
logic  [2:0]  mux_cfg_l0p_linkmode;          // L0p Mux: Target Link Width
// Signals to qualify Link Mode request
logic         int_l0p_linkmode_valid;        // Indicates that the programmed Link Mode encoding is valid
logic  [5:0]  int_l0p_linkmode_onehot;       // mux_cfg_l0p_linkmode converted to one-hot encoding
logic         int_l0p_linkmode_request;      // Indicates that the requested Link Width change request can be executed
logic         int_l0p_linkmode_ready;        // The controller is ready to accept Link Width change request on the Configuration Interface
logic         int_cmd_linkmode_ready;        // L0p Control FSM is ready to accept Link Width change request on SDLH L0p mux Interface
// L0p Request Signals
logic         cfg_l0p_linkmode_req_r;        // Static L0p Request
logic         cfg_pcie_l0p_request_r;        // Dynamic L0p Request
// Latched L0p Request
logic         latched_cdm_xdlh_link_req_r;   // Latch L0p Request when back-2-back L0p Link Width change is requested
logic         latched_cdm_xdlh_link_pri_r;   // Latch L0p Priority when back-2-back L0p Link Width change is requested
logic  [2:0]  latched_cdm_xdlh_link_width_r; // Latch L0p Target Link Width when back-2-back L0p Link Width change is requested

// ----------------------------------------------------------------------------
// L0p Negotiation Conditions:
// Upon a reception of link width change from Software on Target Link Width (cfg_l0p_linkmode) in DEV3 Cap -> Device Control 3 Register - Bit[6:4],
// Request Pulse for a directed L0p Link Width change from CDM to XDLH will be asserted based on the following:
// 1- Receiver L0p Supported is set to 1b -> (cfg_receiver_l0p_supported) -> DEV3 Cap, Device Capabilities 3 Register, Bit[3]
// 2- Remote L0p Supported is set to 1b   -> (cfg_remote_l0p_supported)   -> DEV3 Cap, Device Status 3 Register, Bit[4]
// 3- L0p Enable is set is 1b             -> (cfg_l0p_enable)             -> DEV3 Cap, Device Control 3 Register, Bit[3]
// 4- Hardware Autonomous Width Disable is de-asserted 0b -> (cfg_l0p_autowidth_dis) -> PCIE Cap, Link Control Register, Bit [9]
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Qualify L0p Request
//
// Software can only perform a request to change the link width for the following valid values. (0-4)
// These valid values must be less than or equal to the maximum link width
// and must not be equal to the negotiated link width.
// ----------------------------------------------------------------------------
assign int_l0p_linkmode_onehot  = (mux_cfg_l0p_linkmode==3'b000) ? 6'b000001 : (mux_cfg_l0p_linkmode==3'b001) ? 6'b000010 :
                                  (mux_cfg_l0p_linkmode==3'b010) ? 6'b000100 : (mux_cfg_l0p_linkmode==3'b011) ? 6'b001000 : 6'b010000;
assign int_l0p_linkmode_valid   = (int_l0p_linkmode_onehot <= cfg_l0p_max_link_width) &&
                                  (int_l0p_linkmode_onehot != cfg_l0p_neg_link_width);
assign int_l0p_linkmode_request = mux_cfg_l0p_request && int_l0p_linkmode_valid;
assign int_l0p_linkmode_ready   = cfg_l0p_enable && !mux_cfg_l0p_autowidth_dis;

// ----------------------------------------------------------------------------
// Mux between Dynamic and Static L0p configuration interfaces
// ----------------------------------------------------------------------------
// Dynamic L0p is enabled only if target_link_width in dev3 ctl reg is 3'b111
assign mux_cfg_l0p_dynamic_en    = (cfg_l0p_linkmode == 3'b111) ? 1'b1 : 1'b0;

assign mux_cfg_l0p_autowidth_dis = mux_cfg_l0p_dynamic_en ? (cfg_pcie_l0p_disable || cfg_l0p_autowidth_dis) : cfg_l0p_autowidth_dis  ;
assign mux_cfg_l0p_request       = mux_cfg_l0p_dynamic_en ?  cfg_pcie_l0p_request_r                         : cfg_l0p_linkmode_req_r ;
assign mux_cfg_l0p_priority      = mux_cfg_l0p_dynamic_en ?  cfg_pcie_l0p_priority                          : cfg_l0p_priority       ;
assign mux_cfg_l0p_linkmode      = mux_cfg_l0p_dynamic_en ?  cfg_pcie_l0p_linkmode                          : cfg_l0p_linkmode       ;
// pass the l0p_rejected pulse to the output only if in l0p dynamic mode
assign app_dynamic_l0p_rejected  = mux_cfg_l0p_dynamic_en ? xdlh_cdm_link_nak : 1'b0;
assign app_dynamic_l0p_enable    = mux_cfg_l0p_dynamic_en;


// ----------------------------------------------------------------------------
// Static L0p Request
// ----------------------------------------------------------------------------
always @( posedge core_clk or negedge core_rst_n) begin: l0p_static_request
    if (!core_rst_n) begin
      cfg_l0p_linkmode_req_r <= #TP 1'b0;
    end else if (int_l0p_linkmode_ready && cfg_l0p_linkmode_req) begin
      cfg_l0p_linkmode_req_r <= #TP 1'b1;
    end else begin
      cfg_l0p_linkmode_req_r <= #TP 1'b0;
    end
end

// ----------------------------------------------------------------------------
// Dynamic L0p Request
// ----------------------------------------------------------------------------
always @( posedge core_clk or negedge core_rst_n) begin: l0p_dynamic_request
    if (!core_rst_n) begin
      cfg_pcie_l0p_request_r <= #TP 1'b0;
    end else if (int_l0p_linkmode_ready && cfg_pcie_l0p_request) begin
      cfg_pcie_l0p_request_r <= #TP 1'b1;
    end else begin
      cfg_pcie_l0p_request_r <= #TP 1'b0;
    end
end

// ----------------------------------------------------------------------------
// If software performs two or more consecutive write accesses without waiting
// for the ACK then wait for the ongoing L0p request to complete before
// triggering the latched request
// ----------------------------------------------------------------------------
assign int_cmd_linkmode_ready = (cdm_xdlh_link_req ? xdlh_cdm_link_ack : 1'b1) && smlh_ltssm_l0p_ready;

always @( posedge core_clk or negedge core_rst_n) begin : l0p_request
  if (!core_rst_n) begin
    cdm_xdlh_link_dis   <= #TP '0;
    cdm_xdlh_link_req   <= #TP '0;
    cdm_xdlh_link_pri   <= #TP '0;
    cdm_xdlh_link_width <= #TP '0;
  end
  else begin
    cdm_xdlh_link_dis   <= #TP mux_cfg_l0p_autowidth_dis;
    // Reset request on L0p acknowledge
    if (xdlh_cdm_link_ack) begin
      cdm_xdlh_link_req   <= #TP '0;
      cdm_xdlh_link_pri   <= #TP '0;
      cdm_xdlh_link_width <= #TP '0;
    // If link wasn't ready for L0p when request was asserted the drive latched L0p request
    end else if (latched_cdm_xdlh_link_req_r && int_cmd_linkmode_ready && int_l0p_linkmode_valid) begin
      cdm_xdlh_link_req   <= #TP 1'b1;
      cdm_xdlh_link_pri   <= #TP latched_cdm_xdlh_link_pri_r;
      cdm_xdlh_link_width <= #TP latched_cdm_xdlh_link_width_r;
    // If link is ready for L0p when request is asserted then drive L0p request from the configuration interface
    end else if (int_l0p_linkmode_request && int_cmd_linkmode_ready) begin
      cdm_xdlh_link_req   <= #TP 1'b1;
      cdm_xdlh_link_pri   <= #TP mux_cfg_l0p_priority;
      cdm_xdlh_link_width <= #TP mux_cfg_l0p_linkmode;
    end
  end
end : l0p_request

// ----------------------------------------------------------------------------
// If software performs two or more consecutive write accesses without waiting
// for the ACK then latch the last L0p request and wait for the ongoing L0p
// request to complete before triggering a new request
// ----------------------------------------------------------------------------
always_ff @(posedge core_clk or negedge core_rst_n) begin : latch_l0p_request
  if (!core_rst_n) begin
    latched_cdm_xdlh_link_req_r   <= #TP '0;
    latched_cdm_xdlh_link_pri_r   <= #TP '0;
    latched_cdm_xdlh_link_width_r <= #TP '0;
  end else if (int_l0p_linkmode_request && !int_cmd_linkmode_ready) begin
    latched_cdm_xdlh_link_req_r   <= #TP 1'b1;
    latched_cdm_xdlh_link_pri_r   <= #TP mux_cfg_l0p_priority;
    latched_cdm_xdlh_link_width_r <= #TP mux_cfg_l0p_linkmode;
  end else if (int_cmd_linkmode_ready) begin
    latched_cdm_xdlh_link_req_r   <= #TP '0;
    latched_cdm_xdlh_link_pri_r   <= #TP '0;
    latched_cdm_xdlh_link_width_r <= #TP '0;
  end
end : latch_l0p_request


`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule
