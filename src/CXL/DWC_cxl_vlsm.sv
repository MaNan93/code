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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #25 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_vlsm.sv#25 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Link layer VLSM's for CXL.io and CXL.mem/CXL.cache
// Resolved VLSM for interfacing between VLSM's and LTSSM
// ALMP generation for status and request
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "CXL/svif/DWC_cxl_arb_llctrl_if.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_vlsm
  import spif_pkg::*;                               // Import SPIF package
  import DWC_cxl_pkg::*;
  import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
    parameter TP              = `TP
  ) (
  // Interfaces
  spif_if.master_mp   b_vlsm_llctrl_mc,             // Link Layer to VLSM SPIF Interface for CXL.cachemem
  spif_if.master_mp   b_vlsm_llctrl_io,             // Link Layer to VLSM SPIF Interface for CXL.io
  spif_if.slave_mp    b_vlsm_splh_spif,             // VLSM to SPLH SPIF Interface
  // Inputs
  input               core_clk,
  input               core_rst_n,
  // Configuration Interface
  input               cfg_pm_timeout_enable,        // ARB/MUX PM Timeout Control Register - PM Timeout Enable
  input  [1:0]        cfg_pm_timeout_value,         // ARB/MUX PM Timeout Control Register - PM Timeout Value
  output              cfg_pm_timeout_error,         // ARB/MUX Uncorrectable Error Status Register - PM Timeout Error
  input               cfg_vlsm_force_active,        // Force VLSM State to ACTIVE
  input               cfg_vlsm_pm_enable,           // Enable Low Power mode Entry handshake
  input  [3:0]        cfg_cxl_io_arb_weight,        // CXL.io Weighted Round Robin Arbitration Weight
  input  [3:0]        cfg_cxl_mc_arb_weight,        // CXL.cache and CXL.mem Weighted Round Robin Arbitration Weight
// ----------------------------------------------------------------------------
// Power Management Application Interface
// ----------------------------------------------------------------------------
  input               vlsm_io_tx_pm_nak,            // vLSM.io transmit Status(Active.PMNAK) ALMP
  input               vlsm_mc_tx_pm_nak,            // vLSM.mc transmit Status(Active.PMNAK) ALMP
  input  ras_dp_err_inj_t ras_dp_err_inj,           // Rx ALMP checker RASDP error injection
  output ras_dp_err_log_t vlsm_rasdp_err_log,       // Rx ALMP checker RASDP error log
  // Outputs
  output              vlsm_io_rx_pm_nak,            // vLSM.io received Status(Active.PMNAK) ALMP
  output              vlsm_mc_rx_pm_nak,            // vLSM.mc received Status(Active.PMNAK) ALMP
  output              vlsm_io_rx_pm_req,            // vLSM.io PM Request ALMP received
  output              vlsm_mc_rx_pm_req,            // vLSM.mc PM Request ALMP received
  output              vlsm_io_pm_timeout,           // vLSM.io PM Request ALMP timeout
  output              vlsm_mc_pm_timeout,           // vLSM.mc PM Request ALMP timeout
// ----------------------------------------------------------------------------
// Interface with Power Management
// ----------------------------------------------------------------------------
  // Interface with Reset module
  output logic        vlsm_ltssm_enable,            // Enable core_rst_n assertion
  // vLSM Debug Interface
  output vlsm_debug_t vlsm_debug_info               // VLSM Debug Information
);

// Declarations
localparam CXL_IO_VLSM = 1'b1;
localparam CXL_MC_VLSM = 1'b0;

// Declarations
spif_if  b_cfgi_spif();             // CFGI SPIF Interface to propagate to the Link Layer
spif_if  b_rplh_spif();             // RPLH SPIF Interface to propagate to the Link Layer
spif_if  b_smlh_spif();             // SMLH SPIF Interface to propagate to the Link Layer

// CXL.io VLSM Interface with ALMP Generator
logic              s_almp_io_sts_pmnak;            // vLSM.io ALMP Status(Active.PMNAK) received
logic              s_vlsm_io_link_enable;
logic              s_almp_io_req_active;           // vLSM.io ALMP Request(Active) received on ARB/MUX IF
logic              s_vlsm_io_req_sent;             // vLSM.io Request ALMP transmitted
logic              s_vlsm_io_req_l1_rcvd;          // vLSM.io ALMP Request(Active) received 
logic              s_vlsm_io_req_l2_rcvd;          // vLSM.io ALMP Request(Active) received
logic              s_vlsm_io_unexp_error;          // VLSM Unexpected ALMP error 
logic              s_vlsm_io_rx_req_done;          // VLSM RX Request-Status Handshake Done
logic              s_vlsm_io_tx_req_done;          // VLSM TX Request-Status Handshake Done
logic              s_vlsm_io_tx_sts_done;          // VLSM TX Status Exchange Handshake Done
logic              s_vlsm_io_tx_sts_error;         // VLSM TX Status Exchange Handshake Error
logic              s_almp_io_tx_request;           // VLSM requests to transmit ALMP Request
logic              s_almp_io_tx_status;            // VLSM requests to transmit ALMP Status
logic              s_almp_io_tx_sts_ena;           // VLSM enables ALMP Status Response to the received ALMP Request
state_enc_e        s_vlsm_io_link_req_state;       // VLSM Link Requested State
state_enc_e        s_vlsm_io_link_sts_state;       // VLSM Link Status State
state_enc_e        s_vlsm_io_rslvd_state;          // VLSM Resolved State
vlsm_almp_debug_t  s_vlsm_io_almp_debug;           // VLSM ALMP Generator debug information
vlsm_link_debug_t  s_vlsm_io_link_debug;           // Link vLSM debug information

// CXL.cache/mem VLSM Interface with ALMP Generator
logic              s_almp_mc_sts_pmnak;            // vLSM.mc ALMP Status(Active.PMNAK) received
logic              s_vlsm_mc_link_enable;
logic              s_almp_mc_req_active;           // vLSM.mc ALMP Request(Active) received on ARB/MUX IF
logic              s_vlsm_mc_req_sent;             // vLSM.mc Request ALMP transmitted
logic              s_vlsm_mc_req_l1_rcvd;          // vLSM.mc ALMP Request(Active) received 
logic              s_vlsm_mc_req_l2_rcvd;          // vLSM.mc ALMP Request(Active) received
logic              s_vlsm_mc_unexp_error;          // VLSM Unexpected ALMP error 
logic              s_vlsm_mc_rx_req_done;          // VLSM RX Request-Status Handshake Done
logic              s_vlsm_mc_tx_req_done;          // VLSM TX Request-Status Handshake Done
logic              s_vlsm_mc_tx_sts_done;          // VLSM TX Status Exchange Handshake Done
logic              s_vlsm_mc_tx_sts_error;         // VLSM TX Status Exchange Handshake Error
logic              s_almp_mc_tx_request;           // VLSM requests to transmit ALMP Request
logic              s_almp_mc_tx_status;            // VLSM requests to transmit ALMP Status
logic              s_almp_mc_tx_sts_ena;           // VLSM enables ALMP Status Response to the received ALMP Request
state_enc_e        s_vlsm_mc_link_req_state;       // VLSM Link Requested State
state_enc_e        s_vlsm_mc_link_sts_state;       // VLSM Link Status
state_enc_e        s_vlsm_mc_rslvd_state;          // VLSM Resolved State
vlsm_almp_debug_t  s_vlsm_mc_almp_debug;           // VLSM ALMP Generator debug information
vlsm_link_debug_t  s_vlsm_mc_link_debug;           // Link vLSM debug information

// ALMP Decoder Replication Error
logic              s_almp_rx_repl_error;           // ALMP Replication Error
// ALMP Decoder interface with CXL.io ALMP Generator
logic              s_almp_io_rx_request;           // CXL.io Request ALMP Received
logic              s_almp_io_rx_status;            // CXL.io Status ALMP Received
state_enc_e        s_almp_io_rx_link_state;        // CXL.io Received VLSM state
// ALMP Decoder interface with CXL.mem/cach ALMP Generator
logic              s_almp_mc_rx_request;           // CXL.mem/cache Request ALMP Received
logic              s_almp_mc_rx_status;            // CXL.mem/cache Status ALMP Received
state_enc_e        s_almp_mc_rx_link_state;        // CXL.mem/cache Received VLSM state
// ALMP Decoder interface with ALMP Generators
logic              s_almp_tx_en;                   // Enable Transmit/Recive path for ALMP Generator

// ALMP Arbiter interface with ALMP Generators
logic              s_vlsm_arbmux_stall_req;        // ARB/MUX Stall Request
logic              s_vlsm_arbmux_stall_ack;        // ARB/MUX Stall Acknowledge
logic              s_almp_io_trdy;                 // Physical Layer ready to transmit CXL.io ALMP
logic              s_almp_io_valid_gen;            // CXL.io ALMP Message Valid almp gen output
logic [127:0]      s_almp_io_data_gen;             // CXL.io ALMP Message Data almp gen output
logic              s_almp_io_valid;                // CXL.io ALMP Message Valid
logic [127:0]      s_almp_io_data;                 // CXL.io ALMP Message Data
logic              s_almp_mc_trdy;                 // Physical Layer ready to transmit CXL.cachemem ALMP
logic              s_almp_mc_valid_gen;            // CXL.cachemem ALMP Message Valid almp gen output
logic [127:0]      s_almp_mc_data_gen;             // CXL.cachemem ALMP Message Data almp gen output
logic              s_almp_mc_valid;                // CXL.cachemem ALMP Message Valid
logic [127:0]      s_almp_mc_data;                 // CXL.cachemem ALMP Message Data
logic [ALMP_PROT_W-1:0]  s_almp_io_data_chk;
logic                    s_almp_io_ras_dp_err;
logic [ALMP_PROT_W-1:0]  s_almp_mc_data_chk;
logic                    s_almp_mc_ras_dp_err;
// Internal signals
logic              s_almp_io_bypass;               // Bypass CXL.io ALMP Generation
logic              s_almp_mc_bypass;               // Bypass CXL.cache/mem ALMP Generation
logic              s_vlsm_io_active_req;           // CXL.io VLSM Active Request
logic              s_vlsm_mc_active_req;           // CXL.mem/cache VLSM Active Request
logic              s_vlsm_io_retrain_req;          // CXL.io VLSM Retrain Request
logic              s_vlsm_mc_retrain_req;          // CXL.mem/cache VLSM Retrain Request
logic              s_vlsm_io_disable_req;          // CXL.io VLSM Link Disable Request
logic              s_vlsm_mc_disable_req;          // CXL.mem/cache VLSM Link Disable Request
logic              s_vlsm_io_linkreset_req;        // CXL.io VLSM Link Reset Request
logic              s_vlsm_mc_linkreset_req;        // CXL.mem/cache VLSM Link Reset Request
logic              s_vlsm_io_trdy;                 // Physical Layer is ready to accept CXL.io flit
logic              s_vlsm_mc_trdy;                 // Physical Layer is ready to accept CXL.cachemem flit

vlsm_info_debug_t  s_vlsm_pl_info_debug;           // vLSM Physical and Link Layer Common Debug Information Bus
logic              s_vlsm_state_l1;                // vLSM FSM is in L1 state
logic              s_vlsm_state_l2;                // vLSM FSM is in L2 state
logic              s_cfg_vlsm_force_active;        // Register Force VLSM State to ACTIVE
logic              s_ltssm_in_l0;                  // Physical Link is in L0 notification from LTSSM
logic              s_ltssm_in_training;            // Physical Link is in Recovery notification from LTSSM
logic              s_cxl_device_type;              // CXL Device Type is an inverted cxl_device_mode, where 0 - Root-Complex, 1 - Endpoint
protocol_cfg_t     vlsm_protocol_cfg;              // Protocol Configuration for ARB/MUX
logic              s_cxl_pcie_flit_mode;           // CXL 256B Flit Mode
logic              s_cfg_pm_timeout_enable;        // ARB/MUX PM Timeout Control Register - PM Timeout Enable
logic [1:0]        s_cfg_pm_timeout_value;         // ARB/MUX PM Timeout Control Register - PM Timeout Value
logic              s_cfg_pm_timeout_error;         // ARB/MUX PM Timeout Control Register - PM Timeout Enable

// Invert cxl_device_mode as vLSM implementation uses inverted version of this signal
assign s_cxl_device_type     = !b_vlsm_splh_spif.s_pl_device_port;

// -------------------------------------------------------------------------------------
// Protocol Decoder Instantiation to be used on the hierarchy level
// -------------------------------------------------------------------------------------
spif_protocol_dec
 u_spif_protocol (
    // Inputs
    .core_clk        ( core_clk                           ),
    .core_rst_n      ( core_rst_n                         ),
    .pl_protocol_vld ( b_vlsm_splh_spif.s_pl_protocol_vld ),
    .pl_protocol     ( b_vlsm_splh_spif.s_pl_protocol     ),
    .pl_protocol_fmt ( b_vlsm_splh_spif.s_pl_protocol_fmt ),
    // Outputs
    .pl_protocol_cfg ( vlsm_protocol_cfg                  )
);
// -------------------------------------------------------------------------------------

assign s_vlsm_io_link_enable = 1'b1;
assign s_vlsm_mc_link_enable = (b_vlsm_llctrl_io.s_pl_state_sts != RESET);

// ----------------------------------------------------------------------------
// vLSM Debug Information Bus
// ----------------------------------------------------------------------------
assign vlsm_debug_info = '{
    pl_info: s_vlsm_pl_info_debug,
    mc_link: s_vlsm_mc_link_debug,
    mc_almp: s_vlsm_mc_almp_debug,
    io_link: s_vlsm_io_link_debug,
    io_almp: s_vlsm_io_almp_debug
};
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// vLSM Physical and Link Layer Common Debug Information Bus
// ----------------------------------------------------------------------------
assign s_vlsm_pl_info_debug = '{
    almp_unexp_err  : (s_vlsm_io_unexp_error || s_vlsm_mc_unexp_error),
    almp_repl_err   : s_almp_rx_repl_error,
    pl_protocol_vld : b_vlsm_splh_spif.s_pl_protocol_vld,
    pl_protocol     : b_vlsm_splh_spif.s_pl_protocol,
    pl_stall_req    : b_vlsm_splh_spif.s_pl_stall_req,
    pl_stall_ack    : b_vlsm_splh_spif.s_lp_stall_ack,
    pl_state_req    : b_vlsm_splh_spif.s_lp_state_req,
    pl_state_sts    : b_vlsm_splh_spif.s_pl_state_sts,
    mc_state_req    : b_vlsm_llctrl_mc.s_lp_state_req,
    mc_state_sts    : b_vlsm_llctrl_mc.s_pl_state_sts,
    io_state_req    : b_vlsm_llctrl_io.s_lp_state_req,
    io_state_sts    : b_vlsm_llctrl_io.s_pl_state_sts
};
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// CDM Interface Input/Output register
// ----------------------------------------------------------------------------
assign s_cfg_pm_timeout_error = vlsm_protocol_cfg.cxl_pcie_flit_mode && s_cxl_device_type && (vlsm_io_pm_timeout || vlsm_mc_pm_timeout);

delay_n
 #(
    .N     (1),
    .WD    (1 + 4)
) u_delay_cdm_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({  cfg_vlsm_force_active ,   cfg_pm_timeout_enable,   cfg_pm_timeout_value , s_cfg_pm_timeout_error}),
    .dout  ({s_cfg_vlsm_force_active , s_cfg_pm_timeout_enable, s_cfg_pm_timeout_value ,   cfg_pm_timeout_error})
);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// SPIF Interface Mappings
// ----------------------------------------------------------------------------

// Extract SMLH Interface Status Signals on SPIF Interface
assign b_smlh_spif.s_pl_device_port   = b_vlsm_splh_spif.s_pl_device_port  ;
assign b_smlh_spif.s_pl_phyinl1       = b_vlsm_splh_spif.s_pl_phyinl1      ;
assign b_smlh_spif.s_pl_phyinl2       = b_vlsm_splh_spif.s_pl_phyinl2      ;
assign b_smlh_spif.s_pl_phyinretrain  = b_vlsm_splh_spif.s_pl_phyinretrain ;
assign b_smlh_spif.s_pl_phyinrxl0s    = b_vlsm_splh_spif.s_pl_phyinrxl0s   ;
assign b_smlh_spif.s_pl_phyrcvdeiosq  = b_vlsm_splh_spif.s_pl_phyrcvdeiosq ;
assign b_smlh_spif.s_pl_speedmode     = b_vlsm_splh_spif.s_pl_speedmode    ;
assign b_smlh_spif.s_pl_bw_ratio      = b_vlsm_splh_spif.s_pl_bw_ratio     ;
assign b_smlh_spif.s_pl_linkmode      = b_vlsm_splh_spif.s_pl_linkmode     ;
assign b_smlh_spif.s_pl_protocol_vld  = b_vlsm_splh_spif.s_pl_protocol_vld ;
assign b_smlh_spif.s_pl_protocol      = b_vlsm_splh_spif.s_pl_protocol     ;
assign b_smlh_spif.s_pl_protocol_fmt  = b_vlsm_splh_spif.s_pl_protocol_fmt ;
assign b_smlh_spif.s_pl_inband_pres   = b_vlsm_splh_spif.s_pl_inband_pres  ;
assign b_smlh_spif.s_pl_link_up       = b_vlsm_splh_spif.s_pl_link_up      ;
assign b_smlh_spif.s_pl_link_down     = b_vlsm_splh_spif.s_pl_link_down    ;

// Extract RPLH Interface Signals on SPIF Interface
assign b_rplh_spif.s_pl_stream        = b_vlsm_splh_spif.s_pl_stream       ;
assign b_rplh_spif.s_pl_valid         = b_vlsm_splh_spif.s_pl_valid        ;
assign b_rplh_spif.s_pl_data          = b_vlsm_splh_spif.s_pl_data         ;
assign b_rplh_spif.s_pl_data_chk      = b_vlsm_splh_spif.s_pl_data_chk     ;
assign b_rplh_spif.s_pl_crc_valid     = b_vlsm_splh_spif.s_pl_crc_valid    ;
assign b_rplh_spif.s_pl_crc_data      = b_vlsm_splh_spif.s_pl_crc_data     ;
assign b_rplh_spif.s_pl_rx_flush      = b_vlsm_splh_spif.s_pl_rx_flush     ;
assign b_rplh_spif.s_pl_rx_nak        = b_vlsm_splh_spif.s_pl_rx_nak       ;
assign b_rplh_spif.s_pl_dlp_start     = b_vlsm_splh_spif.s_pl_dlp_start    ;
assign b_rplh_spif.s_pl_dlp_end       = b_vlsm_splh_spif.s_pl_dlp_end      ;
assign b_rplh_spif.s_pl_tlp_start     = b_vlsm_splh_spif.s_pl_tlp_start    ;
assign b_rplh_spif.s_pl_tlp_end       = b_vlsm_splh_spif.s_pl_tlp_end      ;
assign b_rplh_spif.s_pl_tlp_edb       = b_vlsm_splh_spif.s_pl_tlp_edb      ;
assign b_rplh_spif.s_pl_error         = b_vlsm_splh_spif.s_pl_error        ;
assign b_rplh_spif.s_pl_nullified     = b_vlsm_splh_spif.s_pl_nullified    ;
assign b_rplh_spif.s_pl_poisoned      = b_vlsm_splh_spif.s_pl_poisoned     ;
assign b_rplh_spif.s_pl_dllp_valid    = b_vlsm_splh_spif.s_pl_dllp_valid   ;
assign b_rplh_spif.s_pl_dllp_ofc      = b_vlsm_splh_spif.s_pl_dllp_ofc     ;
assign b_rplh_spif.s_pl_dllp_data     = b_vlsm_splh_spif.s_pl_dllp_data    ;

// DLLP interface is applicable only to PCIe/CXL.io SPIF interface
assign b_vlsm_splh_spif.s_lp_dllp_valid = b_vlsm_llctrl_io.s_lp_dllp_valid ;
assign b_vlsm_splh_spif.s_lp_dllp_data  = b_vlsm_llctrl_io.s_lp_dllp_data  ;
assign b_vlsm_splh_spif.s_lp_dllp_ofc   = b_vlsm_llctrl_io.s_lp_dllp_ofc   ;

// CFGI SPIF Interface Connections
assign b_vlsm_splh_spif.s_lp_cfg_vld  = b_cfgi_spif.s_lp_cfg_vld           ;
assign b_vlsm_splh_spif.s_lp_cfg_data = b_cfgi_spif.s_lp_cfg_data          ;
assign b_cfgi_spif.s_pl_cfg_vld       = b_vlsm_splh_spif.s_pl_cfg_vld      ;
assign b_cfgi_spif.s_pl_cfg_data      = b_vlsm_splh_spif.s_pl_cfg_data     ;

// Not connected, tie-off
assign b_cfgi_spif.s_lp_cfg_vld       = '0;
assign b_cfgi_spif.s_lp_cfg_data      = '0;

// Temporary connect to PCIe/CXL.io SPIF interface when not in CXL mode
assign b_vlsm_splh_spif.s_lp_linkmode_rmt  = vlsm_protocol_cfg.cxl_mode_enable ? '0 : b_vlsm_llctrl_io.s_lp_linkmode_rmt;
assign b_vlsm_splh_spif.s_lp_linkmode_pri  = vlsm_protocol_cfg.cxl_mode_enable ? '0 : b_vlsm_llctrl_io.s_lp_linkmode_pri;
assign b_vlsm_splh_spif.s_lp_linkmode      = vlsm_protocol_cfg.cxl_mode_enable ? '0 : b_vlsm_llctrl_io.s_lp_linkmode    ;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Instantiation of VLSM Controller with following functionality:
// 1) ARB/MUX Multiple Virtual LSM Resolution Table
// 2) VLSM Control/Status Outputs
// 3) CXL Interface with Reset Controller
// ----------------------------------------------------------------------------
DWC_cxl_vlsm_fsm
 u_cxl_vlsm_fsm (
    // Inputs
    .core_clk               ( core_clk                              ),
    .core_rst_n             ( core_rst_n                            ),
    .pcie_mode_enable       ( vlsm_protocol_cfg.pcie_mode_enable    ),
    .cxl_mode_enable        ( vlsm_protocol_cfg.cxl_mode_enable     ),
    .vlsm_pl_rx_active_req  ( b_vlsm_splh_spif.s_pl_rx_active_req   ),
    .vlsm_pl_stall_req      ( b_vlsm_splh_spif.s_pl_stall_req       ),
    .vlsm_pl_state_sts      ( b_vlsm_splh_spif.s_pl_state_sts       ),
    .vlsm_pl_phyinretrain   ( b_vlsm_splh_spif.s_pl_phyinretrain    ),
    .almp_rx_repl_error     ( s_almp_rx_repl_error                  ),
    .vlsm_io_lp_state_req   ( b_vlsm_llctrl_io.s_lp_state_req       ),
    .vlsm_io_active_req     ( s_vlsm_io_active_req                  ),
    .vlsm_mc_active_req     ( s_vlsm_mc_active_req                  ),
    .vlsm_io_retrain_req    ( s_vlsm_io_retrain_req                 ),
    .vlsm_mc_retrain_req    ( s_vlsm_mc_retrain_req                 ),
    .vlsm_io_disable_req    ( s_vlsm_io_disable_req                 ),
    .vlsm_mc_disable_req    ( s_vlsm_mc_disable_req                 ),
    .vlsm_io_linkreset_req  ( s_vlsm_io_linkreset_req               ),
    .vlsm_mc_linkreset_req  ( s_vlsm_mc_linkreset_req               ),
    .vlsm_io_link_state     ( b_vlsm_llctrl_io.s_pl_state_sts       ),
    .vlsm_mc_link_state     ( b_vlsm_llctrl_mc.s_pl_state_sts       ),
    .vlsm_io_linkerror      ( b_vlsm_llctrl_io.s_lp_linkerror       ),
    .vlsm_mc_linkerror      ( b_vlsm_llctrl_mc.s_lp_linkerror       ),
    .vlsm_io_wake_req       ( b_vlsm_llctrl_io.s_lp_wake_req        ),
    .vlsm_mc_wake_req       ( b_vlsm_llctrl_mc.s_lp_wake_req        ),
    .vlsm_io_clk_ack        ( b_vlsm_llctrl_io.s_lp_clk_ack         ),
    .vlsm_mc_clk_ack        ( b_vlsm_llctrl_mc.s_lp_clk_ack         ),
    .vlsm_io_rx_active_sts  ( b_vlsm_llctrl_io.s_lp_rx_active_sts   ),
    .vlsm_mc_rx_active_sts  ( b_vlsm_llctrl_mc.s_lp_rx_active_sts   ),
    .vlsm_io_dl_active      ( b_vlsm_llctrl_io.s_lp_dl_active       ),
    .vlsm_mc_dl_active      ( b_vlsm_llctrl_mc.s_lp_dl_active       ),
    .vlsm_io_stall_ack      ( b_vlsm_llctrl_io.s_lp_stall_ack       ),
    .vlsm_mc_stall_ack      ( b_vlsm_llctrl_mc.s_lp_stall_ack       ),
    .vlsm_arbmux_stall_req  ( s_vlsm_arbmux_stall_req               ),
    // Outputs
    .vlsm_arbmux_stall_ack  ( s_vlsm_arbmux_stall_ack               ),
    .vlsm_lp_linkerror      ( b_vlsm_splh_spif.s_lp_linkerror       ),
    .vlsm_lp_wake_req       ( b_vlsm_splh_spif.s_lp_wake_req        ),
    .vlsm_lp_clk_ack        ( b_vlsm_splh_spif.s_lp_clk_ack         ),
    .vlsm_lp_dl_active      ( b_vlsm_splh_spif.s_lp_dl_active       ),
    .vlsm_lp_rx_active_sts  ( b_vlsm_splh_spif.s_lp_rx_active_sts   ),
    .vlsm_lp_stall_ack      ( b_vlsm_splh_spif.s_lp_stall_ack       ),
    .vlsm_lp_state_req      ( b_vlsm_splh_spif.s_lp_state_req       ),
    .ltssm_in_training      ( s_ltssm_in_training                   ),
    .ltssm_in_l0            ( s_ltssm_in_l0                         ),
    .vlsm_state_l1          ( s_vlsm_state_l1                       ),
    .vlsm_state_l2          ( s_vlsm_state_l2                       ),
    .vlsm_ltssm_enable      ( vlsm_ltssm_enable                     )
);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// CXL.io VLSM and ALMP Generation
// ----------------------------------------------------------------------------
DWC_cxl_vlsm_link_fsm
 #(
    .STREAM_ID              ( SID_CXL_IO                            ),
    .PM_PHASE1_ENABLE       ( 1                                     )
) u_cxl_io_vlsm (
    // Interfaces
    .b_vlsm_llctrl          ( b_vlsm_llctrl_io                      ),
    .b_rplh_spif            ( b_rplh_spif.rplh_slave_mp             ),
    .b_smlh_spif            ( b_smlh_spif.smlh_sts_slave_mp         ),
    // Inputs
    .core_clk               ( core_clk                              ),
    .core_rst_n             ( core_rst_n                            ),
    .cxl_device_type        ( s_cxl_device_type                     ),
    .cxl_pcie_flit_mode     ( vlsm_protocol_cfg.cxl_pcie_flit_mode  ),
    .cfg_vlsm_pm_enable     ( 1'b1                                  ),
    .cfg_vlsm_force_active  ( s_cfg_vlsm_force_active               ),
    .pl_clk_req             ( b_vlsm_splh_spif.s_pl_clk_req         ),
    .pl_wake_ack            ( b_vlsm_splh_spif.s_pl_wake_ack        ),
    .pl_rx_active_req       ( b_vlsm_splh_spif.s_pl_rx_active_req   ),
    .pl_block_dl_init       ( b_vlsm_splh_spif.s_pl_block_dl_init   ),
    .pl_stall_req           ( b_vlsm_splh_spif.s_pl_stall_req       ),
    .pl_state_sts           ( b_vlsm_splh_spif.s_pl_state_sts       ),
    .pl_dllp_trdy           ( b_vlsm_splh_spif.s_pl_dllp_trdy       ),
    .pl_skip_trdy           ( b_vlsm_splh_spif.s_pl_skip_trdy       ),
    .pl_trdy                ( s_vlsm_io_trdy                        ),
    .vlsm_bypass_enable     ( !vlsm_protocol_cfg.cxl_mode_enable    ),
    .vlsm_link_enable       ( s_vlsm_io_link_enable                 ),
    .vlsm_rx_req_done       ( s_vlsm_io_rx_req_done                 ),
    .vlsm_tx_req_done       ( s_vlsm_io_tx_req_done                 ),
    .vlsm_tx_sts_done       ( s_vlsm_io_tx_sts_done                 ),
    .vlsm_tx_sts_error      ( s_vlsm_io_tx_sts_error                ),
    .vlsm_almp_req_sent     ( s_vlsm_io_req_sent                    ),
    .vlsm_almp_req_l1_rcvd  ( s_vlsm_io_req_l1_rcvd                 ),
    .vlsm_almp_req_l2_rcvd  ( s_vlsm_io_req_l2_rcvd                 ),
    .vlsm_almp_unexp_error  ( s_vlsm_io_unexp_error                 ),
    .vlsm_almp_rslvd_state  ( s_vlsm_io_rslvd_state                 ),
    .almp_pm_req_timeout    ( vlsm_io_pm_timeout                    ),
    .vlsm_tx_sts_pmnak      ( vlsm_io_tx_pm_nak                     ),
    .almp_rx_sts_pmnak      ( s_almp_io_sts_pmnak                   ),
    // Outputs
    .almp_rx_req_active     ( s_almp_io_req_active                  ),
    .almp_tx_request        ( s_almp_io_tx_request                  ),
    .almp_tx_status         ( s_almp_io_tx_status                   ),
    .almp_tx_sts_ena        ( s_almp_io_tx_sts_ena                  ),
    .almp_tx_sts_state      ( s_vlsm_io_link_sts_state              ),
    .almp_tx_req_state      ( s_vlsm_io_link_req_state              ),
    .vlsm_link_debug_info   ( s_vlsm_io_link_debug                  ),
    .vlsm_link_active_req   ( s_vlsm_io_active_req                  ),
    .vlsm_link_retrain_req  ( s_vlsm_io_retrain_req                 ),
    .vlsm_link_disable_req  ( s_vlsm_io_disable_req                 ),
    .vlsm_link_reset_req    ( s_vlsm_io_linkreset_req               )
);

// ----------------------------------------------------------------------------
// CXL.io ALMP Generation
// ----------------------------------------------------------------------------
DWC_cxl_almp_gen
 #(
    .VLSM_IO_INSTANCE      ( CXL_IO_VLSM                            )
) u_cxl_io_almp_gen (
    .core_clk              ( core_clk                               ),
    .core_rst_n            ( core_rst_n                             ),
    .cxl_device_type       ( s_cxl_device_type                      ),
    .cxl_pcie_flit_mode    ( vlsm_protocol_cfg.cxl_pcie_flit_mode   ),
    .cfg_pm_timeout_enable ( s_cfg_pm_timeout_enable                ),
    .cfg_pm_timeout_value  ( s_cfg_pm_timeout_value                 ),
    .link_in_training      ( s_ltssm_in_training                    ),
    .almp_tx_en            ( s_almp_tx_en                           ),
    .almp_arb_halt         ( !s_almp_io_trdy                        ),
    .almp_bypass           ( 1'b0                                   ),
    .almp_rx_request       ( s_almp_io_rx_request                   ),
    .almp_rx_status        ( s_almp_io_rx_status                    ),
    .almp_rx_link_state    ( s_almp_io_rx_link_state                ),
    .almp_tx_request       ( s_almp_io_tx_request                   ),
    .almp_tx_status        ( s_almp_io_tx_status                    ),
    .almp_tx_sts_ena       ( s_almp_io_tx_sts_ena                   ),
    .vlsm_link_sts_state   ( s_vlsm_io_link_sts_state               ),
    .vlsm_link_req_state   ( s_vlsm_io_link_req_state               ),
    .vlsm_rx_req_done      ( s_vlsm_io_rx_req_done                  ),
    .vlsm_tx_req_done      ( s_vlsm_io_tx_req_done                  ),
    .vlsm_tx_sts_done      ( s_vlsm_io_tx_sts_done                  ),
    .vlsm_tx_sts_error     ( s_vlsm_io_tx_sts_error                 ),
    .almp_pm_req_timeout   ( vlsm_io_pm_timeout                     ),
    .almp_pm_req_rcvd      ( vlsm_io_rx_pm_req                      ),
    .almp_rx_sts_pmnak     ( s_almp_io_sts_pmnak                    ),
    .almp_rx_pm_nak        ( vlsm_io_rx_pm_nak                      ),
    .almp_rx_req_active    ( s_almp_io_req_active                   ),
    .vlsm_almp_req_sent    ( s_vlsm_io_req_sent                     ),
    .vlsm_almp_req_l1_rcvd ( s_vlsm_io_req_l1_rcvd                  ),
    .vlsm_almp_req_l2_rcvd ( s_vlsm_io_req_l2_rcvd                  ),
    .vlsm_almp_unexp_error ( s_vlsm_io_unexp_error                  ),
    .vlsm_almp_rslvd_state ( s_vlsm_io_rslvd_state                  ),
    .vlsm_almp_debug_info  ( s_vlsm_io_almp_debug                   ),
    .almp_valid            ( s_almp_io_valid_gen                    ),
    .almp_data             ( s_almp_io_data_gen                     )
);


// ----------------------------------------------------------------------------
// CXL.cache/mem VLSM and ALMP Generation
// ----------------------------------------------------------------------------
DWC_cxl_vlsm_link_fsm
 #(
    .STREAM_ID              ( SID_CXL_CM                            ),
    .PM_PHASE1_ENABLE       ( 1                                     )
) u_cxl_mc_vlsm (
    // Interfaces
    .b_vlsm_llctrl          ( b_vlsm_llctrl_mc                      ),
    .b_rplh_spif            ( b_rplh_spif.rplh_slave_mp             ),
    .b_smlh_spif            ( b_smlh_spif.smlh_sts_slave_mp         ),
    // Inputs
    .core_clk               ( core_clk                              ),
    .core_rst_n             ( core_rst_n                            ),
    .cxl_device_type        ( s_cxl_device_type                     ),
    .cxl_pcie_flit_mode     ( vlsm_protocol_cfg.cxl_pcie_flit_mode  ),
    .cfg_vlsm_pm_enable     ( cfg_vlsm_pm_enable                    ),
    .cfg_vlsm_force_active  ( s_cfg_vlsm_force_active               ),
    .pl_clk_req             ( b_vlsm_splh_spif.s_pl_clk_req         ),
    .pl_wake_ack            ( b_vlsm_splh_spif.s_pl_wake_ack        ),
    .pl_rx_active_req       ( b_vlsm_splh_spif.s_pl_rx_active_req   ),
    .pl_block_dl_init       ( b_vlsm_splh_spif.s_pl_block_dl_init   ),
    .pl_stall_req           ( b_vlsm_splh_spif.s_pl_stall_req       ),
    .pl_state_sts           ( b_vlsm_splh_spif.s_pl_state_sts       ),
    .pl_dllp_trdy           ( 1'b0                                  ),
    .pl_skip_trdy           ( 1'b0                                  ),
    .pl_trdy                ( s_vlsm_mc_trdy                        ),
    .vlsm_bypass_enable     ( 1'b0                                  ),
    .vlsm_link_enable       ( s_vlsm_mc_link_enable                 ),
    .vlsm_rx_req_done       ( s_vlsm_mc_rx_req_done                 ),
    .vlsm_tx_req_done       ( s_vlsm_mc_tx_req_done                 ),
    .vlsm_tx_sts_done       ( s_vlsm_mc_tx_sts_done                 ),
    .vlsm_tx_sts_error      ( s_vlsm_mc_tx_sts_error                ),
    .vlsm_almp_req_sent     ( s_vlsm_mc_req_sent                    ),
    .vlsm_almp_req_l1_rcvd  ( s_vlsm_mc_req_l1_rcvd                 ),
    .vlsm_almp_req_l2_rcvd  ( s_vlsm_mc_req_l2_rcvd                 ),
    .vlsm_almp_unexp_error  ( s_vlsm_mc_unexp_error                 ),
    .vlsm_almp_rslvd_state  ( s_vlsm_mc_rslvd_state                 ),
    .almp_pm_req_timeout    ( vlsm_mc_pm_timeout                    ),
    .vlsm_tx_sts_pmnak      ( vlsm_mc_tx_pm_nak                     ),
    .almp_rx_sts_pmnak      ( s_almp_mc_sts_pmnak                   ),
    // Outputs
    .almp_rx_req_active     ( s_almp_mc_req_active                  ),
    .almp_tx_request        ( s_almp_mc_tx_request                  ),
    .almp_tx_status         ( s_almp_mc_tx_status                   ),
    .almp_tx_sts_ena        ( s_almp_mc_tx_sts_ena                  ),
    .almp_tx_sts_state      ( s_vlsm_mc_link_sts_state              ),
    .almp_tx_req_state      ( s_vlsm_mc_link_req_state              ),
    .vlsm_link_debug_info   ( s_vlsm_mc_link_debug                  ),
    .vlsm_link_active_req   ( s_vlsm_mc_active_req                  ),
    .vlsm_link_retrain_req  ( s_vlsm_mc_retrain_req                 ),
    .vlsm_link_disable_req  ( s_vlsm_mc_disable_req                 ),
    .vlsm_link_reset_req    ( s_vlsm_mc_linkreset_req               )
);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// CXL.cache/mem ALMP Generation
// ----------------------------------------------------------------------------
DWC_cxl_almp_gen
 #(
    .VLSM_IO_INSTANCE      ( CXL_MC_VLSM                            )
) u_cxl_mc_almp_gen (
    .core_clk              ( core_clk                               ),
    .core_rst_n            ( core_rst_n                             ),
    .cxl_device_type       ( s_cxl_device_type                      ),
    .cxl_pcie_flit_mode    ( vlsm_protocol_cfg.cxl_pcie_flit_mode   ),
    .cfg_pm_timeout_enable ( s_cfg_pm_timeout_enable                ),
    .cfg_pm_timeout_value  ( s_cfg_pm_timeout_value                 ),
    .link_in_training      ( s_ltssm_in_training                    ),
    .almp_tx_en            ( s_almp_tx_en                           ),
    .almp_arb_halt         ( !s_almp_mc_trdy                        ),
    .almp_bypass           ( 1'b0                                   ),
    .almp_rx_request       ( s_almp_mc_rx_request                   ),
    .almp_rx_status        ( s_almp_mc_rx_status                    ),
    .almp_rx_link_state    ( s_almp_mc_rx_link_state                ),
    .almp_tx_request       ( s_almp_mc_tx_request                   ),
    .almp_tx_status        ( s_almp_mc_tx_status                    ),
    .almp_tx_sts_ena       ( s_almp_mc_tx_sts_ena                   ),
    .vlsm_link_sts_state   ( s_vlsm_mc_link_sts_state               ),
    .vlsm_link_req_state   ( s_vlsm_mc_link_req_state               ),
    .vlsm_rx_req_done      ( s_vlsm_mc_rx_req_done                  ),
    .vlsm_tx_req_done      ( s_vlsm_mc_tx_req_done                  ),
    .vlsm_tx_sts_done      ( s_vlsm_mc_tx_sts_done                  ),
    .vlsm_tx_sts_error     ( s_vlsm_mc_tx_sts_error                 ),
    .almp_pm_req_timeout   ( vlsm_mc_pm_timeout                     ),
    .almp_pm_req_rcvd      ( vlsm_mc_rx_pm_req                      ),
    .almp_rx_sts_pmnak     ( s_almp_mc_sts_pmnak                    ),
    .almp_rx_pm_nak        ( vlsm_mc_rx_pm_nak                      ),
    .almp_rx_req_active    ( s_almp_mc_req_active                   ),
    .vlsm_almp_req_sent    ( s_vlsm_mc_req_sent                     ),
    .vlsm_almp_req_l1_rcvd ( s_vlsm_mc_req_l1_rcvd                  ),
    .vlsm_almp_req_l2_rcvd ( s_vlsm_mc_req_l2_rcvd                  ),
    .vlsm_almp_unexp_error ( s_vlsm_mc_unexp_error                  ),
    .vlsm_almp_rslvd_state ( s_vlsm_mc_rslvd_state                  ),
    .vlsm_almp_debug_info  ( s_vlsm_mc_almp_debug                   ),
    .almp_valid            ( s_almp_mc_valid_gen                    ),
    .almp_data             ( s_almp_mc_data_gen                     )
);
// ----------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL Received ALMP Message Decoder
// -------------------------------------------------------------------------------------
DWC_cxl_almp_dec
 u_cxl_almp_dec (
    // Interfaces
    .b_rplh_spif           ( b_rplh_spif.rplh_slave_mp              ),
    // Inputs
    .core_clk              ( core_clk                               ),
    .core_rst_n            ( core_rst_n                             ),
    .cxl_device_type       ( s_cxl_device_type                      ),
    .cxl_pcie_flit_mode    ( vlsm_protocol_cfg.cxl_pcie_flit_mode   ),
    .cxl_link_up           ( b_vlsm_splh_spif.s_pl_link_up          ),
    .almp_rx_en            ( b_vlsm_splh_spif.s_lp_rx_active_sts    ),
    .ras_dp_err_inj        ( ras_dp_err_inj                         ),
    .rx_almp_rasdp_err_log ( vlsm_rasdp_err_log                     ),
    // Outputs
    .almp_rx_repl_error    ( s_almp_rx_repl_error                   ),
    .almp_tx_en            ( s_almp_tx_en                           ),
    .almp_io_rx_request    ( s_almp_io_rx_request                   ),
    .almp_io_rx_status     ( s_almp_io_rx_status                    ),
    .almp_io_rx_link_state ( s_almp_io_rx_link_state                ),
    .almp_mc_rx_request    ( s_almp_mc_rx_request                   ),
    .almp_mc_rx_status     ( s_almp_mc_rx_status                    ),
    .almp_mc_rx_link_state ( s_almp_mc_rx_link_state                )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL ARB/MUX Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_arb_mux
 u_cxl_arb_mux (
    .core_clk              ( core_clk                          ),
    .core_rst_n            ( core_rst_n                        ),
    .cfg_cxl_io_arb_weight ( cfg_cxl_io_arb_weight             ),
    .cfg_cxl_mc_arb_weight ( cfg_cxl_mc_arb_weight             ),
    .pcie_flit_mode        ( vlsm_protocol_cfg.pcie_flit_mode  ),
    .pcie_nfm_mode         ( vlsm_protocol_cfg.pcie_nfm_mode   ),
    // CXL.io ALMP Message Interface
    .almp_io_valid         ( s_almp_io_valid                   ),
    .almp_io_data          ( s_almp_io_data                    ),
    .almp_io_trdy          ( s_almp_io_trdy                    ),
    // CXL.io Link Layer to vLSM SPIF Interface
    .almp_io_data_chk      ( s_almp_io_data_chk                ),
    // CXL.io Link Layer to vLSM SPIF Interface
    .vlsm_io_stream        ( b_vlsm_llctrl_io.s_lp_stream      ),
    .vlsm_io_irdy          ( b_vlsm_llctrl_io.s_lp_irdy        ),
    .vlsm_io_pri           ( b_vlsm_llctrl_io.s_lp_pri         ),
    .vlsm_io_valid         ( b_vlsm_llctrl_io.s_lp_valid       ),
    .vlsm_io_data          ( b_vlsm_llctrl_io.s_lp_data        ),
    .vlsm_io_dlp_start     ( b_vlsm_llctrl_io.s_lp_dlp_start   ),
    .vlsm_io_dlp_end       ( b_vlsm_llctrl_io.s_lp_dlp_end     ),
    .vlsm_io_tlp_start     ( b_vlsm_llctrl_io.s_lp_tlp_start   ),
    .vlsm_io_tlp_end       ( b_vlsm_llctrl_io.s_lp_tlp_end     ),
    .vlsm_io_data_chk      ( b_vlsm_llctrl_io.s_lp_data_chk    ),
    .vlsm_io_rasdp_error   ( b_vlsm_llctrl_io.s_lp_rasdp_error ),
    .vlsm_io_nop_flit      ( b_vlsm_llctrl_io.s_lp_nop_flit    ),
    .vlsm_io_trdy          ( s_vlsm_io_trdy                    ),
    // CXL.cachemem ALMP Message Interface
    .almp_mc_valid         ( s_almp_mc_valid                   ),
    .almp_mc_data          ( s_almp_mc_data                    ),
    .almp_mc_trdy          ( s_almp_mc_trdy                    ),
    // CXL.cachemem Link Layer to vLSM SPIF Interface
    .almp_mc_data_chk      ( s_almp_mc_data_chk                ),
    // CXL.cachemem Link Layer to vLSM SPIF Interface
    .vlsm_mc_stream        ( b_vlsm_llctrl_mc.s_lp_stream      ),
    .vlsm_mc_irdy          ( b_vlsm_llctrl_mc.s_lp_irdy        ),
    .vlsm_mc_pri           ( b_vlsm_llctrl_mc.s_lp_pri         ),
    .vlsm_mc_valid         ( b_vlsm_llctrl_mc.s_lp_valid       ),
    .vlsm_mc_data          ( b_vlsm_llctrl_mc.s_lp_data        ),
    .vlsm_mc_crc_valid     ( b_vlsm_llctrl_mc.s_lp_crc_valid   ),
    .vlsm_mc_crc_data      ( b_vlsm_llctrl_mc.s_lp_crc_data    ),
    .vlsm_mc_data_chk      ( b_vlsm_llctrl_mc.s_lp_data_chk    ),
    .vlsm_mc_rasdp_error   ( b_vlsm_llctrl_mc.s_lp_rasdp_error ),
    .vlsm_mc_nop_flit      ( b_vlsm_llctrl_mc.s_lp_nop_flit    ),
    .vlsm_mc_corrupt_crc   ( b_vlsm_llctrl_mc.s_lp_corrupt_crc ),
    .vlsm_mc_trdy          ( s_vlsm_mc_trdy                    ),
    // vLSM to Physical Layer SPIF Interface
    .vlsm_pl_trdy          ( b_vlsm_splh_spif.s_pl_trdy        ),
    .vlsm_pl_stall_req     ( s_vlsm_arbmux_stall_req           ),
    .vlsm_lp_stall_ack     ( s_vlsm_arbmux_stall_ack           ),
    .vlsm_lp_irdy          ( b_vlsm_splh_spif.s_lp_irdy        ),
    .vlsm_lp_pri           ( b_vlsm_splh_spif.s_lp_pri         ),
    .vlsm_lp_valid         ( b_vlsm_splh_spif.s_lp_valid       ),
    .vlsm_lp_data          ( b_vlsm_splh_spif.s_lp_data        ),
    .vlsm_lp_crc_valid     ( b_vlsm_splh_spif.s_lp_crc_valid   ),
    .vlsm_lp_crc_data      ( b_vlsm_splh_spif.s_lp_crc_data    ),
    .vlsm_lp_dlp_start     ( b_vlsm_splh_spif.s_lp_dlp_start   ),
    .vlsm_lp_dlp_end       ( b_vlsm_splh_spif.s_lp_dlp_end     ),
    .vlsm_lp_tlp_start     ( b_vlsm_splh_spif.s_lp_tlp_start   ),
    .vlsm_lp_tlp_end       ( b_vlsm_splh_spif.s_lp_tlp_end     ),
    .vlsm_lp_data_chk      ( b_vlsm_splh_spif.s_lp_data_chk    ),
    .vlsm_lp_rasdp_error   ( b_vlsm_splh_spif.s_lp_rasdp_error ),
    .vlsm_lp_nop_flit      ( b_vlsm_splh_spif.s_lp_nop_flit    ),
    .vlsm_lp_corrupt_crc   ( b_vlsm_splh_spif.s_lp_corrupt_crc ),
    .vlsm_lp_stream        ( b_vlsm_splh_spif.s_lp_stream      )
);
// -------------------------------------------------------------------------------------

DWC_cxl_almp_rasdp_wrap
 u_DWC_cxl_almp_rasdp_wrap (
  .core_clk                ( core_clk             ),
  .core_rst_n              ( core_rst_n           ),
  .almp_io_valid_i         ( s_almp_io_valid_gen  ),
  .almp_io_data_i          ( s_almp_io_data_gen   ),
  .almp_mc_valid_i         ( s_almp_mc_valid_gen  ),
  .almp_mc_data_i          ( s_almp_mc_data_gen   ),
  .almp_io_valid_o         ( s_almp_io_valid      ),
  .almp_io_data_o          ( s_almp_io_data       ),
  .almp_io_data_chk_o      ( s_almp_io_data_chk   ),
  .almp_mc_valid_o         ( s_almp_mc_valid      ),
  .almp_mc_data_o          ( s_almp_mc_data       ),
  .almp_mc_data_chk_o      ( s_almp_mc_data_chk   )
);


// -------------------------------------------------------------------------------------
// Imitate ARB/MUX vLSM Interface for testbench (To be removed!!!)
// -------------------------------------------------------------------------------------
DWC_cxl_arb_llctrl_if   b_tx_arbmux_vlsm();

assign b_tx_arbmux_vlsm.s_arb_mux_flit_halt = !b_vlsm_splh_spif.s_pl_trdy;
assign b_tx_arbmux_vlsm.s_arb_mux_flit_vld  = b_vlsm_splh_spif.s_lp_irdy && (b_vlsm_splh_spif.s_lp_stream == SID_ALMP) && (s_almp_io_valid && s_almp_io_trdy || s_almp_mc_valid && s_almp_mc_trdy);
assign b_tx_arbmux_vlsm.s_arb_mux_flit_sof  = b_tx_arbmux_vlsm.s_arb_mux_flit_vld;
assign b_tx_arbmux_vlsm.s_arb_mux_flit_eof  = '0; // Not used in the testbench
assign b_tx_arbmux_vlsm.s_arb_mux_flit_enf  = '0; // Not used in the tesbench
assign b_tx_arbmux_vlsm.s_arb_mux_flit_data = b_tx_arbmux_vlsm.s_arb_mux_flit_sof ? {{(`CX_ARBMUX_FLIT_PROT_WIDTH){1'b0}}, {(ARBMUX_FLIT_WD - (32*`CX_NW)){1'b0}}, b_vlsm_splh_spif.s_lp_data} : '0;
// -------------------------------------------------------------------------------------

endmodule
