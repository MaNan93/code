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
// ---   $DateTime: 2024/01/12 11:11:14 $
// ---   $Revision: #6 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_crd_arb.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Credit Return Arbitration
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_crd_arb
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
)
                                    (
// Inputs ------------------------------------------------------------------------------
    input                             core_clk,               // Core Clock
    input                             core_rst_n,             // Core Reset
    input                             cxl_pcie_flit_mode,     // CXL 256B Flit Mode
    input                             cxl_ll_init_done,       // CXL Link Initialization is complete, enable credit exchange
    input                             cxl_init_mem_crd,       // Initialize CXL.mem credits
    input                             cxl_init_cache_crd,     // Initialize CXL.cache credits
    input                             cfg_cache_enable,       // CXL.cache protocol enable
    input                             cfg_mem_enable,         // CXL.mem protocol enable
    input [FLIT_CRD_WD-1:0]           cxl_cache_data_crdret,  // RX Credit Return - 68B Flit RX Credit Return for CXL.cache Data
    input [FLIT_CRD_WD-1:0]           cxl_cache_rsp_crdret,   // RX Credit Return - 68B Flit RX Credit Return for CXL.cache Response
    input [FLIT_CRD_WD-1:0]           cxl_cache_req_crdret,   // RX Credit Return - 68B Flit RX Credit Return for CXL.cache Request
    input CRD_256B_t                  cxl_cache_256B_crdret,  // RX Credit Return - 256B Flit RX Credit Return for CXL.cache
    input [FLIT_CRD_WD-1:0]           cxl_mem_data_crdret,    // RX Credit Return - 68B Flit RX Credit Return for CXL.mem Data
    input [FLIT_CRD_WD-1:0]           cxl_mem_req_crdret,     // RX Credit Return - 68B Flit RX Credit Return for CXL.mem Request
    input [FLIT_CRD_WD-1:0]           cxl_mem_rsp_crdret,     // RX Credit Return - 68B Flit RX Credit Return for CXL.mem Response
    input CRD_256B_t                  cxl_mem_256B_crdret,    // RX Credit Return - 256B Flit RX Credit Return for CXL.mem
// Outputs -----------------------------------------------------------------------------
    output CRD_256B_t                 cxl_crd_arb_256B_crd,   // Flit Formation - 256B Flit RX Credit Return (2B CRD)
    output logic [FLIT_CRD_WD-1:0]    cxl_crd_arb_data_crd,   // Flit Formation - 68B Flit Data Credit Return for Flit Header
    output logic [FLIT_CRD_WD-1:0]    cxl_crd_arb_rsp_crd,    // Flit Formation - 68B Flit Response Credit Return for Flit Header
    output logic [FLIT_CRD_WD-1:0]    cxl_crd_arb_req_crd     // Flit Formation - 68B Flit Request Credit Return for Flit Header
);

// If both CXL.mem and CXL.cache are enabled the arbitration is required for the credit return fields
localparam NUM_CLIENTS = 2;
localparam ARB_REG_OUT = 0;

// Logic Declarations
logic                      s_cache_data_crd_req; // Cache Data Credit Return Arbitration Request
logic                      s_mem_data_crd_req;   // Mem Data Credit Return Arbitration Request
logic [NUM_CLIENTS-1:0]    s_data_crd_req;       // Data Credit Return Arbitration Request
logic                      s_cache_rsp_crd_req;  // Cache Response Credit Return Arbitration Request
logic                      s_mem_rsp_crd_req;    // Mem Response Credit Return Arbitration Request
logic [NUM_CLIENTS-1:0]    s_rsp_crd_req;        // Response Credit Return Arbitration Request
logic                      s_cache_req_crd_req;  // Cache Request Credit Return Arbitration Request
logic                      s_mem_req_crd_req;    // Mem Request Credit Return Arbitration Request
logic [NUM_CLIENTS-1:0]    s_req_crd_req;        // Request Credit Return Arbitration Request
logic                      s_cache_crd_mask;     // Cache Credit Return Arbitration Mask
logic                      s_mem_crd_mask;       // Mem Credit Return Arbitration Mask
logic [NUM_CLIENTS-1:0]    s_crd_arb_mask;       // Credit Return Arbitration Mask
logic                      s_cache_data_grnt;    // Credit Return granted to Cache Data
logic                      s_cache_rsp_grnt;     // Credit Return granted to Cache Response
logic                      s_cache_req_grnt;     // Credit Return granted to Cache Request
logic                      s_mem_data_grnt;      // Credit Return granted to Mem Data
logic                      s_mem_rsp_grnt;       // Credit Return granted to Mem Response
logic                      s_mem_req_grnt;       // Credit Return granted to Mem Request
logic [FLIT_CRD_WD-1:0]    s_crd_arb_data_crd;   // Data Credit Return Arbitration Result
logic [FLIT_CRD_WD-1:0]    s_crd_arb_rsp_crd;    // Response Credit Return Arbitration Result
logic [FLIT_CRD_WD-1:0]    s_crd_arb_req_crd;    // Request Credit Return Arbitration Result
CRD_256B_t                 s_crd_arb_256B_crd;   // 256B Flit Credit Return Arbitration Result


// Arbitration mask generation when initializing cache credits or if CXL.mem is not enabled
assign s_mem_crd_mask = cxl_init_cache_crd || !cfg_mem_enable || !cxl_ll_init_done;
// Arbitration mask generation when initializing mem credits or if CXL.cache is not enabled
assign s_cache_crd_mask = cxl_init_mem_crd || !cfg_cache_enable || !cxl_ll_init_done;
assign s_crd_arb_mask = {s_cache_crd_mask, s_mem_crd_mask};

// Arbitrate Data Credit Return
assign s_cache_data_crd_req = cxl_pcie_flit_mode ? (|cxl_cache_256B_crdret.CRD_B) : (|cxl_cache_data_crdret[CRD_RET_WD-1:0]);
assign s_mem_data_crd_req   = cxl_pcie_flit_mode ? (|cxl_mem_256B_crdret.CRD_B  ) : (|cxl_mem_data_crdret[CRD_RET_WD-1:0]);
assign s_data_crd_req       = {s_cache_data_crd_req, s_mem_data_crd_req};

DWC_pcie_ctl_bcm55
 #(
  .N            (NUM_CLIENTS),
  .OUTPUT_MODE  (ARB_REG_OUT)
) u_data_crd_arb (
    .clk          (core_clk),
    .rst_n        (core_rst_n),
    .init_n       (1'b1),
    .enable       (1'b1),
    .request      (s_data_crd_req),
    .mask         (s_crd_arb_mask),
    .granted      (),
    .grant        ({s_cache_data_grnt, s_mem_data_grnt}),
    .grant_index  ()
);

// Arbitrate Response Credit Return
assign s_cache_rsp_crd_req = cxl_pcie_flit_mode ? (|cxl_cache_256B_crdret.CRD_C) : (|cxl_cache_rsp_crdret[CRD_RET_WD-1:0]);
assign s_mem_rsp_crd_req   = cxl_pcie_flit_mode ? (|cxl_mem_256B_crdret.CRD_C) : (|cxl_mem_rsp_crdret[CRD_RET_WD-1:0]);
assign s_rsp_crd_req       = {s_cache_rsp_crd_req, s_mem_rsp_crd_req};

DWC_pcie_ctl_bcm55
 #(
  .N            (NUM_CLIENTS),
  .OUTPUT_MODE  (ARB_REG_OUT)
) u_rsp_crd_arb (
    .clk          (core_clk),
    .rst_n        (core_rst_n),
    .init_n       (1'b1),
    .enable       (1'b1),
    .request      (s_rsp_crd_req),
    .mask         (s_crd_arb_mask),
    .granted      (),
    .grant        ({s_cache_rsp_grnt, s_mem_rsp_grnt}),
    .grant_index  ()
);

// Arbitrate Request Credit Return
assign s_cache_req_crd_req = cxl_pcie_flit_mode ? (|cxl_cache_256B_crdret.CRD_A) : (|cxl_cache_req_crdret[CRD_RET_WD-1:0]);
assign s_mem_req_crd_req   = cxl_pcie_flit_mode ? (|cxl_mem_256B_crdret.CRD_A) : (|cxl_mem_req_crdret[CRD_RET_WD-1:0]);
assign s_req_crd_req       = {s_cache_req_crd_req, s_mem_req_crd_req};

DWC_pcie_ctl_bcm55
 #(
  .N            (NUM_CLIENTS),
  .OUTPUT_MODE  (ARB_REG_OUT)
) u_req_crd_arb (
    .clk          (core_clk),
    .rst_n        (core_rst_n),
    .init_n       (1'b1),
    .enable       (1'b1),
    .request      (s_req_crd_req),
    .mask         (s_crd_arb_mask),
    .granted      (),
    .grant        ({s_cache_req_grnt, s_mem_req_grnt}),
    .grant_index  ()
);

// Data Credits
always_comb begin : data_arb_proc
  // Grant Mem
  if (s_mem_data_grnt)
    s_crd_arb_data_crd = cxl_mem_data_crdret;
  // Grant Cache
  else if (s_cache_data_grnt)
    s_crd_arb_data_crd = cxl_cache_data_crdret;
  // Hold Previous
  else
    s_crd_arb_data_crd = '0;//cxl_crd_arb_data_crd;
end : data_arb_proc

// Response Credits
always_comb begin : rsp_arb_proc
  // Grant Mem
  if (s_mem_rsp_grnt)
    s_crd_arb_rsp_crd = cxl_mem_rsp_crdret;
  // Grant Cache
  else if (s_cache_rsp_grnt)
    s_crd_arb_rsp_crd = cxl_cache_rsp_crdret;
  // Hold Previous
  else
    s_crd_arb_rsp_crd = '0;//cxl_crd_arb_rsp_crd;
end : rsp_arb_proc

// Request Credits
always_comb begin : req_arb_proc
  // Grant Mem
  if (s_mem_req_grnt)
    s_crd_arb_req_crd = cxl_mem_req_crdret;
  // Grant Cache
  else if (s_cache_req_grnt)
    s_crd_arb_req_crd = cxl_cache_req_crdret;
  // Hold Previous
  else
    s_crd_arb_req_crd = '0;//cxl_crd_arb_req_crd;
end : req_arb_proc

// 256B Flit Credits
always_comb begin : arb_256B_proc
    s_crd_arb_256B_crd.CRD_A = s_mem_req_grnt  ? cxl_mem_256B_crdret.CRD_A : (s_cache_req_grnt  ? cxl_cache_256B_crdret.CRD_A : '0);
    s_crd_arb_256B_crd.CRD_B = s_mem_data_grnt ? cxl_mem_256B_crdret.CRD_B : (s_cache_data_grnt ? cxl_cache_256B_crdret.CRD_B : '0);
    s_crd_arb_256B_crd.CRD_C = s_mem_rsp_grnt  ? cxl_mem_256B_crdret.CRD_C : (s_cache_rsp_grnt  ? cxl_cache_256B_crdret.CRD_C : '0);
    s_crd_arb_256B_crd.RSVD  = '0; // Reserved
end : arb_256B_proc

assign cxl_crd_arb_data_crd = s_crd_arb_data_crd;
assign cxl_crd_arb_rsp_crd  = s_crd_arb_rsp_crd;
assign cxl_crd_arb_req_crd  = s_crd_arb_req_crd;
assign cxl_crd_arb_256B_crd = s_crd_arb_256B_crd;

endmodule
