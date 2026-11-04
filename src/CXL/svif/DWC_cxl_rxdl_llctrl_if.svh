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
// ---   $Revision: #6 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/svif/DWC_cxl_rxdl_llctrl_if.svh#6 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_CXL_RXDL_LLCTRL_IF__SVH__
`define __GUARD__DWC_CXL_RXDL_LLCTRL_IF__SVH__
interface DWC_cxl_rxdl_llctrl_if
  import DWC_cxl_pkg::*;
  #();

  // Receiver Interface
  logic                                         s_cxl_rx_crc_err;             // CRC error received
  logic                                         s_cxl_rx_retry_ack;           // Retry.Ack received
  logic [(MAX_RETRY_WD - 1) : 0]                s_cxl_rx_rack_num_retry;      // Num Retry Field from the Retry.Ack flit
  logic [(MAX_RETRY_WD - 1) : 0]                s_cxl_rx_req_num_retry;       // NUM_RETRY value from the Retry.Req
  logic [(ESEQ_WD - 1) : 0]                     s_cxl_rx_eseq;                // Echo the ESEQ value from the Retry.Req
  logic                                         s_cxl_rx_retry_req;           // Received Retry Request
  logic [(ACK_CNT_WD - 1) : 0]                  s_cxl_rx_full_ack;            // Full Ack Count from the receiver
  logic                                         s_cxl_rx_rcvd_init_param;     // Init.Param flit received
  logic                                         s_cxl_rx_rcvd_retry;          // A Retry control flit has been received
  logic                                         s_cxl_rx_rcvd_non_retry;      // A non-Retry control flit has been received
  logic                                         s_cxl_rx_rcvd_retry_ack_empty;// Empty bit indicates that the LLR contains no valid data and therefore the NUM_RETRY value should be reset
  logic [1:0]                                   s_cxl_rx_cache_data_valid;    // Receiver offloaded from cache data queue
  logic [(CACHE_REQ_VALID_WD - 1) : 0]          s_cxl_rx_cache_req_valid;     // Receiver offloaded from cache request queu
  logic [(CACHE_RSP_VALID_WD - 1) : 0]          s_cxl_rx_cache_rsp_valid;     // Receiver offloaded from cache response queue
  logic [1:0]                                   s_cxl_rx_mem_data_valid;      // Receiver offloaded from mem data queue
  logic [(MEM_NDR_VALID_WD - 1) : 0]            s_cxl_rx_mem_ndr_valid;       // Receiver offloaded from mem Request queue
  logic [MEM_BI_VALID_WD-1:0]                   s_cxl_rx_mem_bi_valid       ; // Number of CXL.mem BI Snoop/Response messages offloaded from Receive Queue
  logic [(FLIT_CRD_WD - 1) : 0]                 s_cxl_rx_data_crd;            // Received Data Credits
  logic [(FLIT_CRD_WD - 1) : 0]                 s_cxl_rx_rsp_crd;             // Received Response Credits
  logic [(FLIT_CRD_WD - 1) : 0]                 s_cxl_rx_req_crd;             // Received Request Credits
  CRD_256B_t                                    s_cxl_rx_256B_crd;            // RX Credit Return in 256B Flit Mode - received 2B CRD field
  logic                                         s_cxl_lrsm_drop_flits;        // LRSM is active this means all received non LLCTRL retry flits must be discarded
  logic                                         s_cxl_vlsm_recovery;          // vLSM is in recovery


  modport master_mp(
    output s_cxl_rx_crc_err,
    output s_cxl_rx_retry_ack,
    output s_cxl_rx_rack_num_retry,
    output s_cxl_rx_req_num_retry,
    output s_cxl_rx_eseq,
    output s_cxl_rx_retry_req,
    output s_cxl_rx_full_ack,
    output s_cxl_rx_rcvd_init_param,
    output s_cxl_rx_rcvd_retry,
    output s_cxl_rx_rcvd_non_retry,
    output s_cxl_rx_rcvd_retry_ack_empty,
    output s_cxl_rx_cache_data_valid,
    output s_cxl_rx_cache_req_valid,
    output s_cxl_rx_cache_rsp_valid,
    output s_cxl_rx_mem_data_valid,
    output s_cxl_rx_mem_ndr_valid,
    output s_cxl_rx_mem_bi_valid,
    output s_cxl_rx_data_crd,
    output s_cxl_rx_rsp_crd,
    output s_cxl_rx_req_crd,
    output s_cxl_rx_256B_crd,
    input  s_cxl_lrsm_drop_flits,
    input  s_cxl_vlsm_recovery
  );

  modport slave_mp(
    input  s_cxl_rx_crc_err,
    input  s_cxl_rx_retry_ack,
    input  s_cxl_rx_rack_num_retry,
    input  s_cxl_rx_req_num_retry,
    input  s_cxl_rx_eseq,
    input  s_cxl_rx_retry_req,
    input  s_cxl_rx_full_ack,
    input  s_cxl_rx_rcvd_init_param,
    input  s_cxl_rx_rcvd_retry,
    input  s_cxl_rx_rcvd_non_retry,
    input  s_cxl_rx_rcvd_retry_ack_empty,
    input  s_cxl_rx_cache_data_valid,
    input  s_cxl_rx_cache_req_valid,
    input  s_cxl_rx_cache_rsp_valid,
    input  s_cxl_rx_mem_data_valid,
    input  s_cxl_rx_mem_ndr_valid,
    input  s_cxl_rx_mem_bi_valid,
    input  s_cxl_rx_data_crd,
    input  s_cxl_rx_rsp_crd,
    input  s_cxl_rx_req_crd,
    input  s_cxl_rx_256B_crd,
    output s_cxl_lrsm_drop_flits,
    output s_cxl_vlsm_recovery
  );

endinterface : DWC_cxl_rxdl_llctrl_if

`endif // __GUARD__DWC_CXL_RXDL_LLCTRL_IF__SVH__
