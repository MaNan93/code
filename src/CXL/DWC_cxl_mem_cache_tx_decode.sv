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
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx_decode.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Decodes transmitted Flits to extract Credit Return Fields
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_tx_decode
  import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)
                                    (
  input                                 cxl_device_mode,        // 0 - Endpoint; 1 - Root Complex Device
  input                                 cxl_flit_valid,         // Flit Valid
  input [127:0]                         cxl_flit_data,          // Flit Data - Slot 0
  input                                 cxl_flit_all_data,      // All data flit flag
  input                                 cxl_flit_halt,          // Flit halt
  input                                 cxl_pcie_flit_mode,     // PCIe FLit mode enable
  output CRD_256B_t                     cxl_256B_tx_crdret,     // 256B credit return
  output logic                          cxl_ack_timer_rst,      // Reset Acknowledge Flash Time
  output logic [(ACK_CNT_WD - 1) : 0]   cxl_full_ack            // Full ack field
  ,
  output logic [(CRD_RET_WD - 1) : 0]   cxl_cache_data_crd,     // Cache data credit transmitted
  output logic [(CRD_RET_WD - 1) : 0]   cxl_cache_req_crd,      // Cache request credit transmitted
  output logic [(CRD_RET_WD - 1) : 0]   cxl_cache_rsp_crd       // Cache response credit transmitted
  ,
  output logic [(CRD_RET_WD - 1) : 0]   cxl_mem_req_crd,        // Mem request transmitted credits
  output logic [(CRD_RET_WD - 1) : 0]   cxl_mem_rsp_crd,        // Mem response transmitted credits
  output logic [(CRD_RET_WD - 1) : 0]   cxl_mem_data_crd        // Mem Data Credit transmitted
);

localparam [3:0] LLCRD  = 4'h0;
localparam [3:0] ACK    = 4'h1;

// Declarations
logic        cxl_flit_valid_s;
logic        cxl_llcrd_valids_s;
logic        cxl_prot_valids_s;
logic [63:0] cxl_llcrd_payload_s;

// Flit is being transmitted
assign cxl_flit_valid_s    = cxl_flit_valid && !cxl_flit_all_data && !cxl_flit_halt && (cxl_prot_valids_s || cxl_llcrd_valids_s);
assign cxl_llcrd_valids_s  = cxl_flit_data[0] && (cxl_flit_data[35:32] == LLCRD) && (cxl_flit_data[39:36] == ACK);
assign cxl_prot_valids_s   = (cxl_pcie_flit_mode)? 1'b1 : !cxl_flit_data[0] ;
assign cxl_llcrd_payload_s = cxl_flit_data[127:64];

// Extract the acknowledge from either protocol or llcrd flit 
always_comb begin : get_ack_proc
    cxl_full_ack      = '0;
       // Reset Acknowledge Flash Timer if
        // 1) Ack bit is set, or
        // 2) Flit is carrying credit information, or
        // 3) The flit is LLCRD flit and it is carrying Acknowledge information in the payload
    cxl_ack_timer_rst = (cxl_flit_valid_s & cxl_pcie_flit_mode)? |cxl_flit_data[15:0]: 
    ((cxl_flit_valid_s)?
    cxl_flit_data[2] | (|{cxl_flit_data[30:28], cxl_flit_data[26:24], cxl_flit_data[22:20]}) | (cxl_llcrd_valids_s & (|{cxl_llcrd_payload_s[7:4], cxl_llcrd_payload_s[2:0]})): 1'b0);
    if (cxl_flit_valid_s 
 & (!cxl_pcie_flit_mode)) begin
         // Set Ack bit from the Header
        cxl_full_ack[3]   = cxl_flit_data[2];
        // Extract rest of Full Acknowledge bits from LLCRD payload
        if (cxl_llcrd_valids_s) begin
            cxl_full_ack[7:4] = cxl_llcrd_payload_s[7:4];
            cxl_full_ack[2:0] = cxl_llcrd_payload_s[2:0];
        end
    end
end : get_ack_proc

// Extract the credit information from either protocol or llcrd flit 
always_comb begin : get_crd_proc
    cxl_cache_data_crd = {CRD_RET_WD{1'b0}}; 
    cxl_cache_req_crd  = {CRD_RET_WD{1'b0}}; 
    cxl_cache_rsp_crd  = {CRD_RET_WD{1'b0}}; 
    cxl_mem_data_crd   = {CRD_RET_WD{1'b0}};
    cxl_mem_req_crd    = {CRD_RET_WD{1'b0}};
    cxl_mem_rsp_crd    = {CRD_RET_WD{1'b0}};
    if (cxl_flit_valid_s 
 & (!cxl_pcie_flit_mode)) begin
        cxl_cache_data_crd = !cxl_flit_data[31] ? cxl_flit_data[30:28] : {CRD_RET_WD{1'b0}}; 
        cxl_cache_req_crd  = !cxl_flit_data[27] ? cxl_flit_data[26:24] : {CRD_RET_WD{1'b0}}; 
        cxl_cache_rsp_crd  = !cxl_flit_data[23] ? cxl_flit_data[22:20] : {CRD_RET_WD{1'b0}}; 
        cxl_mem_data_crd   = cxl_flit_data[31] ? cxl_flit_data[30:28] : {CRD_RET_WD{1'b0}}; 
        if (!cxl_device_mode) cxl_mem_req_crd    = cxl_flit_data[27] ? cxl_flit_data[26:24] : {CRD_RET_WD{1'b0}}; // Endpoint: M2S Request
        if (cxl_device_mode) cxl_mem_rsp_crd    = cxl_flit_data[23] ? cxl_flit_data[22:20] : {CRD_RET_WD{1'b0}}; // Root-Complex: S2M Response
    end
    
    cxl_256B_tx_crdret = 'b0;
    if (cxl_flit_valid_s  & cxl_pcie_flit_mode) begin
      cxl_256B_tx_crdret.CRD_A = cxl_flit_data[4:0];
      cxl_256B_tx_crdret.CRD_B = cxl_flit_data[9:5];
      cxl_256B_tx_crdret.CRD_C = cxl_flit_data[14:10];
      cxl_256B_tx_crdret.RSVD  = cxl_flit_data[15];
    end
end : get_crd_proc

endmodule
