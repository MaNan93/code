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
// ---   $Revision: #8 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_link_init.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Link Layer initialization.
// Contains link layer initialization FSM.
// Generates Status outputs.
// Generates Error status indications.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_link_init
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
)
                                      (
// Inputs ------------------------------------------------------------------------------
    input                                   core_clk,               // Core clock
    input                                   core_rst_n,             // Core reset
    input                                   cfg_init_stall,         // Stall link initialization
    input                                   cfg_crd_stall,          // Stall credit initialization
    input [(CXL_VERSION_WD - 1) : 0]        cfg_cxl_version,        // CXL Version
    input [(ESEQ_WD - 1) : 0]               cfg_llr_wrap_value,     // Local Sequence number wrap value
    input [(ESEQ_WD - 1) : 0]               cfg_rx_rcvd_llr_wrap,   // Remote partner Sequence counter wrap value
    input                                   cxl_pcie_flit_mode,     // CXL 256B Flit Mode
    input                                   cxl_link_enable,        // CXL.cachemem protocol is enabled
    input                                   cxl_vlsm_init_req,      // VLSM link initalization request
    input                                   cxl_link_crd_ack,       // Credit initialization is complete
    input                                   cxl_rx_rcvd_init_param, // Link layer has received an Init.Param flit
    input                                   cxl_rx_rcvd_retry,      // Link layer has received a Retry flit
    input                                   cxl_rx_rcvd_non_retry,  // non retry flit received
    input                                   cxl_init_param_sent,    // Init.Param flit sent
// Outputs -----------------------------------------------------------------------------
    output logic                            cxl_init_retry_error,   // Link Init Retryable Flit Error
    output logic                            cxl_init_multi_error,   // Link Init Multiple Init.Param Error
    output logic                            cxl_ll_init_crd_done,   // Indicates link initialization is complete
    output logic [(ESEQ_WD - 1) : 0]        cxl_ll_init_llr_wrap,   // Sequence counter wrap value
    output logic                            cxl_ll_init_crd,        // Credit initialization request
    output logic                            cxl_ll_init_done,       // Link Init - INIT.Param exchange done
    output logic [(LL_CSR_STATE_WD-1):0]    cxl_ll_init_state,      // CXL LL Control and Status Register - Init State
    output logic                            cxl_init_param_req,     // Init.Param flit request
    output logic [63:0]                     cxl_init_param_payload  // Init.Param flit payload
);

// Declarations
logic cxl_ll_init_done_s;     // Link Init - INIT.Param exchange done
logic cxl_ll_init_crd_done_s; // Link Initialization is complete
logic cxl_ll_init_param_uc_s; // INIT.Param received after INIT.Param (Uncorrectable Error)
logic cxl_ll_non_retry_uc_s;  // Non-Retry Flit received before INIT.Param (Uncorrectable Error)

// -------------------------------------------------------------------------------------
// Link Initialization FSM
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_link_init_fsm
 u_link_init_fsm (
    .core_clk               ( core_clk               ),
    .core_rst_n             ( core_rst_n             ),
    .cxl_init_param_sent    ( cxl_init_param_sent    ),
    .cfg_init_stall         ( cfg_init_stall         ),
    .cfg_crd_stall          ( cfg_crd_stall          ),
    .cfg_cxl_version        ( cfg_cxl_version        ),
    .cfg_llr_wrap_value     ( cfg_llr_wrap_value     ),
    .cfg_rx_rcvd_llr_wrap   ( cfg_rx_rcvd_llr_wrap   ),
    .cxl_pcie_flit_mode     ( cxl_pcie_flit_mode     ),
    .cxl_link_enable        ( cxl_link_enable        ),
    .cxl_vlsm_init_req      ( cxl_vlsm_init_req      ),
    .cxl_link_crd_ack       ( cxl_link_crd_ack       ),
    .cxl_rx_rcvd_init_param ( cxl_rx_rcvd_init_param ),
    .cxl_rx_rcvd_retry      ( cxl_rx_rcvd_retry      ),
    .cxl_rx_rcvd_non_retry  ( cxl_rx_rcvd_non_retry  ),
    .cxl_ll_init_param_uc   ( cxl_ll_init_param_uc_s ),
    .cxl_ll_non_retry_uc    ( cxl_ll_non_retry_uc_s  ),
    .cxl_ll_init_crd_done   ( cxl_ll_init_crd_done_s ),
    .cxl_ll_init_llr_wrap   ( cxl_ll_init_llr_wrap   ),
    .cxl_ll_init_crd        ( cxl_ll_init_crd        ),
    .cxl_ll_init_done       ( cxl_ll_init_done_s     ),
    .cxl_ll_init_state_reg  ( cxl_ll_init_state      ),
    .cxl_init_param_req     ( cxl_init_param_req     ),
    .cxl_init_param_payload ( cxl_init_param_payload )
);

// -------------------------------------------------------------------------------------
// Output register on the status signals from Initialization FSM
// -------------------------------------------------------------------------------------
delay_n
 #(
    .N     (1),
    .WD    (4)
) u_init_out_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({cxl_ll_init_crd_done_s,cxl_ll_init_done_s,cxl_ll_init_param_uc_s, cxl_ll_non_retry_uc_s}),
    .dout  ({cxl_ll_init_crd_done  ,cxl_ll_init_done, cxl_init_multi_error  , cxl_init_retry_error })
);

endmodule
