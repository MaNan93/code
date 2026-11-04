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
// ---   $DateTime: 2022/04/14 09:36:50 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_crd_ctrl.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Credit Control
// Tracks flow control credits for the transmitter.
// Returns credit from the receiver.
// Forms credit return fields for LLCRD flits and protocol flit headers.
// Generates LLCRD flits and initializes credit.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_crd_ctrl
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) (
// Inputs ------------------------------------------------------------------------------
    input                         core_clk,
    input                         core_rst_n,
    input                         cfg_cache_enable,         // Enable CXL.cache
    input                         cfg_mem_enable,           // Enable CXL.mem
    input [(ACK_CNT_WD - 1) : 0]  cxl_ll_full_ack,          // Acknowledge Counter Value
    input                         cxl_ack_cnt_llcrd_req,    // Request to inject LLCRD flit due to Ack counter threshold or Ack flush timer
    input                         cxl_viral_llcrd_req,      // LLCRD Flit Insertion request in Viral state
    input                         cxl_rbuf_llcrd_req,       // Request to inject LLCRD flit due to retry buffer spaces equal to 2
    input                         cxl_init_llcrd_req,       // Request to initialize link layer credits
    input                         cxl_cache_crdret_done,    // CXL.cache credit return done
    input                         cxl_mem_crdret_done,      // CXL.cache credit return done
    input                         cxl_llcrd_sent,           // CRD LLCRD flit sent
// Outputs -----------------------------------------------------------------------------
    output logic                  cxl_llcrd_req,            // CRD requests LLCRD sequence
    output logic [63:0]           cxl_llcrd_payload,        // CRD requests LLCRD payload
    output logic                  cxl_crd_ctrl_init_cache,  // Initialize cache credits
    output logic                  cxl_crd_ctrl_init_mem,    // Initialize mem credits
    output logic                  cxl_crd_ctrl_init_done    // Credit Initialization acknowledge
);

// Declarations
logic cxl_llcrd_force_det_s; // Link Layer LLCRD forcing request detected
logic cxl_llcrd_force_rst_s; // Link Layer LLCRD forcing request reset
logic cxl_llcrd_force_req_s; // Link Layer LLCRD forcing request next state
logic cxl_llcrd_force_req_r; // Link Layer LLCRD forcing request register

// -------------------------------------------------------------------------------------
// CXL.cache Credit Intialization Request
// -------------------------------------------------------------------------------------
logic cxl_init_cache_crd_s; // CXL.cache credit initialization request next state
logic cxl_init_cache_crd_r; // CXL.cache credit initialization request register

always_comb begin : init_cache_proc
    if (cxl_cache_crdret_done)
        cxl_init_cache_crd_s = 1'b0;
    else if (cxl_init_llcrd_req && cfg_cache_enable)
        cxl_init_cache_crd_s = 1'b1;
    else
        cxl_init_cache_crd_s = cxl_init_cache_crd_r;
end : init_cache_proc

always_ff @(posedge core_clk or negedge core_rst_n) begin : r_init_cache_proc
    if (!core_rst_n)
        cxl_init_cache_crd_r <= # TP 1'b0;
    else
        cxl_init_cache_crd_r <= # TP cxl_init_cache_crd_s;
end : r_init_cache_proc
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL.mem Credit Intialization Request
// -------------------------------------------------------------------------------------
logic cxl_init_mem_crd_s; // CXL.mem credit initialization request next state
logic cxl_init_mem_crd_r; // CXL.mem credit initialization request register

always_comb begin : init_mem_proc
    if (cxl_mem_crdret_done)
        cxl_init_mem_crd_s = 1'b0;
    else if (cxl_init_llcrd_req && cfg_mem_enable)
        cxl_init_mem_crd_s = 1'b1;
    else
        cxl_init_mem_crd_s = cxl_init_mem_crd_r;
end : init_mem_proc

always_ff @(posedge core_clk or negedge core_rst_n) begin : r_init_mem_proc
    if (!core_rst_n)
        cxl_init_mem_crd_r <= # TP 1'b0;
    else
        cxl_init_mem_crd_r <= # TP cxl_init_mem_crd_s;
end : r_init_mem_proc
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Latch LLCRD Force Request
// -------------------------------------------------------------------------------------
// LLCRD request due to viral or retry buffer or ack counter
assign cxl_llcrd_force_det_s = cxl_viral_llcrd_req || cxl_rbuf_llcrd_req || cxl_ack_cnt_llcrd_req;

// LLCRD request
always_comb begin : llcrd_proc
    // Reset LLCRD register - request is acknowledged
    if (cxl_llcrd_force_rst_s)
          cxl_llcrd_force_req_s = 1'b0;
    // Set LLCRD register - request detected
    else if (cxl_llcrd_force_det_s)
        cxl_llcrd_force_req_s = 1'b1;
    else
        cxl_llcrd_force_req_s = cxl_llcrd_force_req_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin : r_llcrd_proc
    if (!core_rst_n) begin
        cxl_llcrd_force_req_r <= # TP 1'b0;
    end else begin
        cxl_llcrd_force_req_r <= # TP cxl_llcrd_force_req_s;
    end
end : r_llcrd_proc
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Instantiate the Credit Control FSM
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_crd_ctrl_fsm
 u_crd_ctrl_fsm (
    .core_clk                 ( core_clk                 ),
    .core_rst_n               ( core_rst_n               ),
    .cxl_init_crd_req         ( cxl_init_llcrd_req       ),
    .cxl_init_cache_crd       ( cxl_init_cache_crd_s     ),
    .cxl_init_mem_crd         ( cxl_init_mem_crd_s       ),
    .cxl_ll_full_ack          ( cxl_ll_full_ack          ),
    .cxl_llcrd_sent           ( cxl_llcrd_sent           ),
    .cxl_llcrd_force_req      ( cxl_llcrd_force_req_s    ),
    .cxl_llcrd_force_rst      ( cxl_llcrd_force_rst_s    ),
    .cxl_llcrd_req            ( cxl_llcrd_req            ),
    .cxl_llcrd_payload        ( cxl_llcrd_payload        ),
    .cxl_crd_ctrl_init_ack    ( cxl_crd_ctrl_init_done   )
    ,
    .cxl_crd_ctrl_init_cache  ( cxl_crd_ctrl_init_cache  )
    ,
    .cxl_crd_ctrl_init_mem    ( cxl_crd_ctrl_init_mem    )
);
// -------------------------------------------------------------------------------------

endmodule
