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
// ---   $DateTime: 2023/06/26 08:32:07 $
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/svif/DWC_cxl_pack_llctrl_if.svh#5 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_CXL_PACK_LLCTRL_IF__SVH__
`define __GUARD__DWC_CXL_PACK_LLCTRL_IF__SVH__
interface DWC_cxl_pack_llctrl_if

  import DWC_cxl_pkg::*;
  #();

  // Packer Interface
  logic                                 s_cxl_packer_valid;       // Transmitter sends a flit
  logic [CXL_DATA_WD-1 : 0]             s_cxl_packer_flit;        // Retryable Flit for transmission
  logic                                 s_cxl_app_pending;        // Indicates pending traffic from app
  logic [CXL_DATA_PROT_WD-1 : 0]        s_cxl_packer_flit_chk;    // Retryable Flit for transmission ECC check
  logic                                 s_cxl_packer_all_data;    // Transmitter sends all data flit
  logic                                 s_cxl_packer_last;        // Packer End of Sequence indication, next flit is header flit
  logic                                 s_cxl_packer_idle;        // Packer Idle state indication
  logic                                 s_cxl_packer_llctrl_halt; // Packer halts LLCTRL flits
  logic                                 s_cxl_hdr_ack_bit;        // When set to 1 indicates that the Ack bit in the Flit header can be set
  logic [(FLIT_CRD_WD - 1) : 0]         s_cxl_hdr_data_crd;       // Data Credit for Flit Header
  logic [(FLIT_CRD_WD - 1) : 0]         s_cxl_hdr_rsp_crd;        // Response Credit for Flit Header
  logic [(FLIT_CRD_WD - 1) : 0]         s_cxl_hdr_req_crd;        // Request Credit for Flit Header
  logic [4:0]                           s_cxl_ll_packer_data_en;  // Flit Packe Data Header Enable
  logic                                 s_cxl_ll_packer_halt;     // Backpressure the flit packer
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_cache_req_valid;    // CXL.cache Request channel valid bit
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_cache_rsp_valid;    // CXL.cache Response channel valid bit
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_cache_dhdr_valid;   // CXL.cache Data channel valid bit
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_mem_ndr_valid;      // CXL.mem Request/Response channel valid bit
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_mem_dr_valid;       // CXL.mem DR channel valid bit
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_mem_bi_valid;       // CXL.mem BI-Snoop/Response packed in the flit
  logic                                 s_cxl_ll_cache_mdh_en;    // Enable Multi-Data-Header for CXL.cache
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_ll_cache_data_gnt;  // Cache Data Grant for transmitter
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_ll_cache_rsp_gnt;   // Cache Response Grant for transmitter
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_ll_cache_req_gnt;   // Cache Request Grant for transmitter
  logic                                 s_cxl_ll_mem_mdh_en;      // Enable Multi-Data-Header for CXL.mem
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_ll_mem_dr_gnt;      // Mem Data Grant for transmitter
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_ll_mem_ndr_gnt;     // Mem NDR Grant for transmitter
  logic [TX_CRDIF_WIDTH-1:0]            s_cxl_ll_mem_bi_gnt;        // Credit Controller - CXL.mem BI-Snoop/Response grant

  modport master_ctrl_mp (
    output  s_cxl_ll_cache_mdh_en,
    output  s_cxl_ll_cache_data_gnt,
    output  s_cxl_ll_cache_rsp_gnt,
    output  s_cxl_ll_cache_req_gnt,
    output  s_cxl_ll_mem_mdh_en,
    output  s_cxl_ll_mem_dr_gnt,
    output  s_cxl_ll_mem_ndr_gnt,
    output  s_cxl_ll_mem_bi_gnt,
    output  s_cxl_hdr_ack_bit,
    output  s_cxl_hdr_data_crd,
    output  s_cxl_hdr_rsp_crd,
    output  s_cxl_hdr_req_crd,
    output  s_cxl_ll_packer_data_en,
    output  s_cxl_ll_packer_halt
  );

  modport slave_ctrl_mp (
    input   s_cxl_ll_cache_mdh_en,
    input   s_cxl_ll_cache_data_gnt,
    input   s_cxl_ll_cache_rsp_gnt,
    input   s_cxl_ll_cache_req_gnt,
    input   s_cxl_ll_mem_mdh_en,
    input   s_cxl_ll_mem_dr_gnt,
    input   s_cxl_ll_mem_ndr_gnt,
    input   s_cxl_ll_mem_bi_gnt,
    input   s_cxl_hdr_ack_bit,
    input   s_cxl_hdr_data_crd,
    input   s_cxl_hdr_rsp_crd,
    input   s_cxl_hdr_req_crd,
    input   s_cxl_ll_packer_data_en,
    input   s_cxl_ll_packer_halt
  );
  
  modport master_pack_mp (
    output  s_cxl_cache_req_valid,
    output  s_cxl_cache_rsp_valid,
    output  s_cxl_cache_dhdr_valid,
    output  s_cxl_mem_ndr_valid,
    output  s_cxl_mem_dr_valid,
    output  s_cxl_mem_bi_valid,
    output  s_cxl_app_pending,
    output  s_cxl_packer_valid,
    output  s_cxl_packer_flit,
    output  s_cxl_packer_all_data,
    output  s_cxl_packer_last,
    output  s_cxl_packer_idle,
    output  s_cxl_packer_llctrl_halt
  );

  modport slave_pack_mp(
    input   s_cxl_cache_req_valid,
    input   s_cxl_cache_rsp_valid,
    input   s_cxl_cache_dhdr_valid,
    input   s_cxl_mem_ndr_valid,
    input   s_cxl_mem_dr_valid,
    input   s_cxl_mem_bi_valid,
    input   s_cxl_packer_valid,
    input   s_cxl_packer_flit,
    input   s_cxl_packer_all_data,
    input   s_cxl_packer_last,
    input   s_cxl_packer_idle,
    input   s_cxl_packer_llctrl_halt
  );
  
  modport master_pack_rasdp_mp (
    output  s_cxl_cache_req_valid,
    output  s_cxl_cache_rsp_valid,
    output  s_cxl_cache_dhdr_valid,
    output  s_cxl_mem_ndr_valid,
    output  s_cxl_mem_dr_valid,
    output  s_cxl_mem_bi_valid,
    output  s_cxl_packer_valid,
    output  s_cxl_packer_flit,
    output  s_cxl_packer_flit_chk,
    output  s_cxl_app_pending,
    output  s_cxl_packer_all_data,
    output  s_cxl_packer_last,
    output  s_cxl_packer_idle,
    output  s_cxl_packer_llctrl_halt
  );

  modport slave_pack_rasdp_mp(
    input   s_cxl_cache_req_valid,
    input   s_cxl_cache_rsp_valid,
    input   s_cxl_cache_dhdr_valid,
    input   s_cxl_mem_ndr_valid,
    input   s_cxl_mem_dr_valid,
    input   s_cxl_mem_bi_valid,
    input   s_cxl_packer_valid,
    input   s_cxl_packer_flit,
    input   s_cxl_packer_flit_chk,
    input   s_cxl_packer_all_data,
    input   s_cxl_packer_last,
    input   s_cxl_packer_idle,
    input   s_cxl_packer_llctrl_halt
  );

endinterface : DWC_cxl_pack_llctrl_if

`endif // __GUARD__DWC_CXL_PACK_LLCTRL_IF__SVH__
