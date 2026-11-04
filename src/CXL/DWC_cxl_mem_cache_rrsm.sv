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
// ---   $Revision: #9 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rrsm.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Remote Retry State Machine
// Responsible for generating Retry.Ack after Retry.Req is received.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_rrsm
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
)(
// Inputs ------------------------------------------------------------------------------
    input                           core_clk,                   // Core clock
    input                           core_rst_n,                 // Core reset
    input                           cfg_viral_satus,            // Viral indication
    input                           cxl_rx_retry_req,           // Received Retry.Req
    input                           cxl_vlsm_recovery,          // Transition to recovery occured
    input                           cxl_rbuf_retry_done,        // All flits have been replayed from the Retry Buffer
    input                           cxl_rbuf_empty,             // Retry Buffer Empty Indication
    input [(RBUF_ADD_WD - 1) : 0]   cxl_rbuf_wr_ptr,            // Retry Buffer Write Pointer 
    input [(RBUF_ADD_WD - 1) : 0]   cxl_rbuf_nfree,             // Retry Buffer Num Free Buff 
    input [(MAX_RETRY_WD - 1) : 0]  cxl_rx_req_num_retry,       // Echo the NUM_RETRY value from the Retry.Req
    input [(ESEQ_WD - 1) : 0]       cxl_rx_eseq,                // Echo the ESEQ value from the Retry.Req
    input                           cxl_rrsm_retry_ack_sent,    // RRSM Retry.Ack sent
// Outputs -----------------------------------------------------------------------------
    output logic                    cxl_rrsm_active,            // RRSM is active so halt flit transmission
    output logic                    cxl_rrsm_rbuf_req,          // Request to retry buffer to replay flits
    output logic                    cxl_rrsm_retry_ack,         // RRSM requests Retry.Ack sequence
    output logic [63:0]             cxl_rrsm_retry_payload      // RRSM requests Retry.Ack payload
);

// -------------------------------------------------------------------------------------
// RRSM FSM Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rrsm_fsm
 u_rrsm_fsm (
    // Inputs
    .core_clk                ( core_clk                ),
    .core_rst_n              ( core_rst_n              ),
    .cfg_viral_satus         ( cfg_viral_satus         ),
    .cxl_rx_retry_req        ( cxl_rx_retry_req        ),
    .cxl_rrsm_retry_ack_sent ( cxl_rrsm_retry_ack_sent ),
    .cxl_vlsm_recovery       ( cxl_vlsm_recovery       ),
    .cxl_rbuf_retry_done     ( cxl_rbuf_retry_done     ),
    .cxl_rbuf_empty          ( cxl_rbuf_empty          ),
    .cxl_rbuf_wr_ptr         ( cxl_rbuf_wr_ptr         ),
    .cxl_rbuf_nfree          ( cxl_rbuf_nfree          ),
    .cxl_rx_num_retry        ( cxl_rx_req_num_retry    ),
    .cxl_rx_eseq             ( cxl_rx_eseq             ),
    // Outputs
    .cxl_rrsm_active         ( cxl_rrsm_active         ),
    .cxl_rrsm_retry_ack      ( cxl_rrsm_retry_ack      ),
    .cxl_rrsm_retry_payload  ( cxl_rrsm_retry_payload  ),
    .cxl_rrsm_rbuf_req       ( cxl_rrsm_rbuf_req       ),
    .cxl_rrsm_state          (                         )
);
// -------------------------------------------------------------------------------------



endmodule
