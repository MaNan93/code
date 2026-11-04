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
// --- RCS information:
// ---  $DateTime: 2023/12/22 07:15:34 $
// ---  $Revision: #4 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/splh.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Packet Layer State Management (SPLH) module
//
// Implements Packet Layer SPIF and Command Interfaces
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
`include "products/cx_pl_pkg.svh"

module splh 
  import cx_pl_pkg::tx_cmd_struct;
  import spif_pkg::IDLE_L1_1;
  import spif_pkg::L2;
  import spif_pkg::ACTIVE_L0S_PMNAK;
  import spif_pkg::protocol_cfg_t;
#(
  parameter  TP            = `TP
) (
// Interfaces --------------------------------------------------------------------------
  spif_if.smlh_slave_mp               b_smlh_spif,            // SMLH SPIF interface
  spif_if.xplh_slave_mp               b_xplh_spif,            // XPLH SPIF interface
  spif_if.rplh_slave_mp               b_rplh_spif,            // RPLH SPIF interface
  spif_if.master_mp                   b_splh_spif,            // SPLH SPIF interface
// Inputs ------------------------------------------------------------------------------
  input                               core_clk,               // Core clock
  input                               core_rst_n,             // Core reset
  input                               xplh_linkerror,         // XPLH Link Error indication
  input                               xplh_splh_cmd_ack,      // Command Complete Acknowledge from XPLH to SPLH
  output  tx_cmd_struct               splh_xplh_cmd,          // Command from SPLH to XPLH
  output                              xplh_xmlh_cmd_ack,      // Command Complete Acknowledge from XPLH to XMLH
  input   tx_cmd_struct               xmlh_xplh_cmd,          // Command from XMLH to XPLH
  output  logic                       splh_cmd_if_pmreq_ack,  // SPLH Command Interface PM Entry Acknowledge to XMLH
  output  logic                       splh_cmd_if_stall_ack,  // SPLH Command Interface Stall Acknowledge to XMLH
  output  logic                       splh_cmd_if_pending,    // SPLH Command Interface Packet Pending Indication to XMLH
  output  logic                       splh_pm_req_l0s,        // Packet Layer requests PM Link FSM to enter L0s
  output  logic                       splh_pm_req_l1,         // Packet Layer requests PM Link FSM to enter L1
  output  logic                       splh_pm_req_l2,         // Packet Layer requests PM Link FSM to enter L2
  output  protocol_cfg_t              pl_protocol_cfg         // Protocol Configuration for PLH Layer
);

logic          splh_cmd_if_ack;       // SPLH Command Interface Acknowledge
tx_cmd_struct  splh_cmd_if_cmd;       // SPLH Command Interface Request

// -------------------------------------------------------------------------------------
// XPLH Command Interface Mux
// -------------------------------------------------------------------------------------
// For CXL mode, XPLH command interface is driven from SPLH
// For PCIe mode, XPLH command interface is driven from XMLH
assign splh_xplh_cmd     = pl_protocol_cfg.spif_enable ? splh_cmd_if_cmd : xmlh_xplh_cmd;
// For CXL mode, command ack from XPLH is irrelevant for XMLH Command Interface
assign xplh_xmlh_cmd_ack = pl_protocol_cfg.spif_enable ? 1'b0 : xplh_splh_cmd_ack;
// For PCIe mode, command ack from XPLH is irrelant, as SPLH to XPLH command interface is not enabled and
// command interface is driven by XMLH
assign splh_cmd_if_ack   = pl_protocol_cfg.spif_enable ? xplh_splh_cmd_ack : 1'b0;
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// SPLH SPIF Instantiation
// -------------------------------------------------------------------------------------
splh_spif
 u_splh_spif (
    // Interfaces
    .b_smlh_spif       ( b_smlh_spif       ),
    .b_xplh_spif       ( b_xplh_spif       ),
    .b_rplh_spif       ( b_rplh_spif       ),
    .b_splh_spif       ( b_splh_spif       ),
    // Outputs
    .core_clk          ( core_clk          ),
    .core_rst_n        ( core_rst_n        ),
    .splh_linkerror    ( xplh_linkerror    ),
    .pl_protocol_cfg   ( pl_protocol_cfg   )
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// SPLH to XPLH Command Interface Instantiation
// -------------------------------------------------------------------------------------
splh_cmd_if
 u_splh_cmd_if (
    // Inputs
    .core_clk              ( core_clk                       ),
    .core_rst_n            ( core_rst_n                     ),
    .cmd_if_enable         ( pl_protocol_cfg.spif_enable    ),
    .splh_flit_mode        ( pl_protocol_cfg.pcie_flit_mode ),
    .lp_irdy               ( b_splh_spif.s_lp_irdy          ),
    .lp_state_req          ( b_splh_spif.s_lp_state_req     ),
    .lp_stall_ack          ( b_splh_spif.s_lp_stall_ack     ),
    .pl_state_sts          ( b_splh_spif.s_pl_state_sts     ),
    .pl_stall_req          ( b_splh_spif.s_pl_stall_req     ),
    .pl_protocol_vld       ( b_splh_spif.s_pl_protocol_vld  ),
    .pl_link_up            ( b_splh_spif.s_pl_link_up || pl_protocol_cfg.cxl_mode_enable ),
    .pl_phyinretrain       ( b_splh_spif.s_pl_phyinretrain  ),
    .splh_cmd_if_ack       ( splh_cmd_if_ack                ),
    // Outputs
    .splh_cmd_if_cmd       ( splh_cmd_if_cmd                ),
    .splh_cmd_if_pmreq_l1  ( splh_pm_req_l1                 ),
    .splh_cmd_if_pmreq_l2  ( splh_pm_req_l2                 ),
    .splh_cmd_if_pmreq_ack ( splh_cmd_if_pmreq_ack          ),
    .splh_cmd_if_stall_ack ( splh_cmd_if_stall_ack          ),
    .splh_cmd_if_pending   ( splh_cmd_if_pending            ) 
);
// -------------------------------------------------------------------------------------
assign splh_pm_req_l0s = (b_splh_spif.s_lp_state_req == ACTIVE_L0S_PMNAK);

endmodule
