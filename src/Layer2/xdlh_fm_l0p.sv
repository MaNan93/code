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
// ---   $DateTime: 2024/01/08 11:48:14 $
// ---   $Revision: #6 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_fm_l0p.sv#6 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// L0P Control 
//
// Description: This module implements the L0P Support Query Negotiation and
// L0P Link Width Configuration.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xdlh_fm_l0p
  import cx_pl_pkg::l0p_dllp_struct;
  import cx_pl_pkg::dllp_struct;
  import cx_pl_pkg::l0p_ack_struct;
  import cx_pl_pkg::L0P_Request;
  import cx_pl_pkg::L0P_Request_Ack;
  import cx_pl_pkg::L0P_Request_Nak;
#(
  parameter TP = `TP
)
                    (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                   core_clk,                   // Core clock
  input                   core_rst_n,                 // Active low asynchronous reset
  //  -------------------------------------------------------------------------------------
  // L0P Interface
  // -------------------------------------------------------------------------------------
  // CDM Interface
  input                   cdm_xdlh_l0p_enabled,       // L0P Enabled
  input                   cfg_l0p_priority,           // L0P priority request
  input                   cfg_upstream_port,                
  input                   cfg_hw_autowidth_dis,       // HW autonomous width disable  
  input                   cdm_xdlh_link_req,          // Request to resize the link
  input   [2 : 0]         cdm_xdlh_link_width,        // Target link width
  output  logic           xdlh_cdm_link_ack,
  output  logic           xdlh_l0p_rejected,
  // LTSSM Interface 
  input                   smlh_l0p_capable,
  input                   smlh_in_rcvry,
  input   [5:0]           smlh_l0p_link_mode,         // Indicate the active lanes and final negotiated link width
  input                   smlh_xdlh_eios_rcvd,
  output  logic           xdlh_smlh_enter_recovery,
  output                  xdlh_smlh_link_req,
  output  logic           xdlh_smlh_link_initiated,
  input                   smlh_ltssm_l0p_ready,
  output  logic [4:0]     xdlh_smlh_link_width,
  // XPLH Interface
  input   logic [2:0]     xplh_flit_count,              // TX Flit Count
  output                  xplh_flit_count_en,           // Enable TX Flit Count
  input   [5:0]           smlh_link_mode,               // Negotiated link width during Cfg state of LTSSM
  // -------------------------------------------------------------------------------------
  // Receiver Interface
  // -------------------------------------------------------------------------------------
  input   l0p_dllp_struct rdlh_l0p_dllp,              // Received L0P DLLP Structure
  input                   rdlh_xdlh_fm_dllp_valid,    // Valid DLLP data
  // -------------------------------------------------------------------------------------
  // Rate Information 
  // -------------------------------------------------------------------------------------
  input   [2 : 0]         current_data_rate,          // Data Rate Negotiated with the PHY
  // -------------------------------------------------------------------------------------
  // XDLH DLLP Generator Interface
  // -------------------------------------------------------------------------------------
  input                   xplh_l0p_dllps_count,
  output  dllp_struct     xdlh_l0p_dllp,              // L0P DLLP
  input   l0p_ack_struct  l0p_dllp_ack                // Acknowledge the L0P DLLP has been Transmitted
);

// -------------------------------------------------------------------------------------
// Logic Declarations
// -------------------------------------------------------------------------------------
logic           s_l0p_cfg_en_timer;
logic           s_rsp_dllp_ack;
logic           xdlh_l0p_timeout_1us;
logic           xdlh_l0p_timeout_4us;
logic           xdlh_l0p_timeout_8us;
logic           xdlh_l0p_timeout_16us;
logic           s_cfg_req_dllp_ack;
logic           xdlh_smlh_link_req_int; 
logic           xdlh_smlh_link_rsp_int;
logic           Request_is_initiated; 
logic [4:0]     xdlh_smlh_link_width_req;
logic [4:0]     xdlh_smlh_link_width_rsp;
logic [3:0]     smlh_l0p_link_mode_map;
l0p_dllp_struct xdlh_l0p_cfg_req_dllp;
l0p_dllp_struct xdlh_l0p_cfg_rsp_dllp;


assign xdlh_smlh_link_req = xdlh_smlh_link_req_int || xdlh_smlh_link_rsp_int;
assign xdlh_smlh_link_initiated = xdlh_smlh_link_req_int;

always_comb begin
     xdlh_smlh_link_width=5'b00000;
  if (xdlh_smlh_link_req_int) 
     xdlh_smlh_link_width = xdlh_smlh_link_width_req;
  else if (xdlh_smlh_link_rsp_int)
     xdlh_smlh_link_width = xdlh_smlh_link_width_rsp;
end

// L0P Link Configuration Master FSM
// Responsible for Generating L0P_Request and L0P Up-Configure Complete DLLP's. 
xdlh_fm_l0p_cfg_req
 u_l0p_cfg_req(
  // Inputs
  .core_clk                     (core_clk),
  .core_rst_n                   (core_rst_n),
  .cdm_l0p_enabled              (cdm_xdlh_l0p_enabled), 
  .cfg_hw_autowidth_dis         (cfg_hw_autowidth_dis), 
  .cdm_xdlh_link_req            (cdm_xdlh_link_req),
  .cdm_xdlh_link_width          (cdm_xdlh_link_width),
  .current_data_rate            (current_data_rate),
  .xdlh_smlh_link_req           (xdlh_smlh_link_req_int),
  .xdlh_smlh_link_width         (xdlh_smlh_link_width_req),
  .xdlh_smlh_enter_recovery     (xdlh_smlh_enter_recovery),
  .smlh_ltssm_l0p_ready         (smlh_ltssm_l0p_ready),
  .xdlh_cdm_link_ack            (xdlh_cdm_link_ack),
  .xdlh_l0p_rejected            (xdlh_l0p_rejected),
  .smlh_l0p_capable             (smlh_l0p_capable),
  .smlh_xdlh_eios_rcvd          (smlh_xdlh_eios_rcvd),
  .xdlh_flit_cnt                (xplh_flit_count),
  .xdlh_en_flit_cnt             (xplh_flit_count_en),
  .xplh_l0p_dllps_count         (xplh_l0p_dllps_count),
  .smlh_link_mode               (smlh_link_mode),
  .smlh_in_rcvry                (smlh_in_rcvry),
  .smlh_l0p_link_mode           (smlh_l0p_link_mode_map),
  .cfg_l0p_priority             (cfg_l0p_priority),
  .l0p_1us_timeout              (xdlh_l0p_timeout_1us),
  .l0p_4us_timeout              (xdlh_l0p_timeout_4us),
  .l0p_16us_timeout             (xdlh_l0p_timeout_16us),
  .l0p_8us_timeout              (xdlh_l0p_timeout_8us),
  .rdlh_l0p_dllp                (rdlh_l0p_dllp),
  .l0p_dllp_ack                 (s_cfg_req_dllp_ack),
  .xdlh_smlh_link_req_responder (xdlh_smlh_link_rsp_int),
  // Outputs
  .xdlh_l0p_en_timer            (s_l0p_cfg_en_timer),
  .Request_is_initiated         (Request_is_initiated),
  .xdlh_l0p_cfg_dllp            (xdlh_l0p_cfg_req_dllp)
);

// 4-bits only required to determine link width
// 0001 x1
// 0010 x2
// 0100 x4
// 1000 x8
// 0000 x16
assign smlh_l0p_link_mode_map = smlh_l0p_link_mode[3:0];

// L0P Link Configuration Slave FSM
// Responsible for Generating L0P_Request_Ack and L0P_Request_Nak DLLP's. 
xdlh_fm_l0p_cfg_rsp
 u_l0p_cfg_rsp(
  // Inputs
  .core_clk                 (core_clk),
  .core_rst_n               (core_rst_n),
  .cdm_l0p_enabled          (cdm_xdlh_l0p_enabled),
  .cfg_l0p_priority         (cfg_l0p_priority),
  .cfg_upstream_port        (cfg_upstream_port), 
  .cfg_hw_autowidth_dis     (cfg_hw_autowidth_dis),    
  .cdm_xdlh_link_req        (cdm_xdlh_link_req),
  .cdm_xdlh_link_width      (cdm_xdlh_link_width),
  .smlh_l0p_link_mode       (smlh_l0p_link_mode_map),
  .smlh_link_mode           (smlh_link_mode),
  .xdlh_smlh_link_req       (xdlh_smlh_link_rsp_int),
  .xdlh_smlh_link_width     (xdlh_smlh_link_width_rsp),
  .smlh_ltssm_l0p_ready     (smlh_ltssm_l0p_ready),
  .smlh_in_rcvry            (smlh_in_rcvry),
  .rdlh_l0p_dllp            (rdlh_l0p_dllp),
  .rdlh_xdlh_fm_dllp_valid  (rdlh_xdlh_fm_dllp_valid),
  .l0p_dllp_ack             (s_rsp_dllp_ack),
  .req_to_l1                (xdlh_smlh_link_req_int),
  .Request_is_initiated     (Request_is_initiated),
  .xplh_l0p_dllps_count     (xplh_l0p_dllps_count),
  // Outputs
  .xdlh_l0p_cfg_dllp        (xdlh_l0p_cfg_rsp_dllp)
);

// L0P Timer
// Responsible for timers which are used to monitor the L0P negotiations
xdlh_fm_l0p_timer
 u_l0p_timer_req(
  // Inputs
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .l0p_en_timer               (s_l0p_cfg_en_timer),
  .current_data_rate          (current_data_rate),
  // Outputs
  .xdlh_l0p_timeout_1us       (xdlh_l0p_timeout_1us),
  .xdlh_l0p_timeout_4us       (xdlh_l0p_timeout_4us),
  .xdlh_l0p_timeout_8us       (xdlh_l0p_timeout_8us),
  .xdlh_l0p_timeout_16us      (xdlh_l0p_timeout_16us)
);

// Decode the DLLP Acknowledge from the DLLP Generation Module and Generate the DLLP Acknowledge for the FSM's
assign s_rsp_dllp_ack = l0p_dllp_ack.ack && ((l0p_dllp_ack.l0p_cmd == L0P_Request_Ack) || (l0p_dllp_ack.l0p_cmd == L0P_Request_Nak));
assign s_cfg_req_dllp_ack = l0p_dllp_ack.ack && ((l0p_dllp_ack.l0p_cmd == L0P_Request));

// L0P DLLP Generation
xdlh_fm_l0p_dllp_gen
 u_l0p_dllp_gen(
  // Inputs
  .core_clk           (core_clk),
  .core_rst_n         (core_rst_n),
  .l0p_cfg_req_dllp   (xdlh_l0p_cfg_req_dllp),
  .l0p_cfg_rsp_dllp   (xdlh_l0p_cfg_rsp_dllp),
  .l0p_cfg_rsp_ack    (s_rsp_dllp_ack),
  .l0p_cfg_req_ack    (s_cfg_req_dllp_ack),
  .smlh_in_rcvry      (smlh_in_rcvry),
  // Outputs
  .xdlh_l0p_dllp      (xdlh_l0p_dllp)
);

endmodule
