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
// ---   $DateTime: 2024/01/08 11:48:14 $
// ---   $Revision: #12 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rx.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Reciever Transaction Layer and DataLink Layer Top Module
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_arb_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_cdmregs_if.svh"
`include "CXL/svif/DWC_cxl_rxdl_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_rxtl_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_app_ch_init_if.svh"
`include "CXL/svif/DWC_cxl_app_ch_if.svh"
`include "CXL/svif/DWC_cxl_ram2p_if.svh"
`include "Spif/pkg/spif_pkg.svh"

module DWC_cxl_mem_cache_rx
  import spif_pkg::protocol_cfg_t;
  import DWC_cxl_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
#(
    parameter TP = `TP
) 
                             (
    DWC_cxl_clk_rst_if.slave_mp                             b_clk                ,  // clock reset interface
    DWC_cxl_arb_llctrl_if.slave_rx_mp                       b_arb_llctrl         ,  // ARB/MUX RX link layer control Interface
    DWC_cxl_cdmregs_if.master_rx_mp                         b_cdm                ,  // RX CDM interface
    input protocol_cfg_t                                    cxl_protocol_cfg     ,  // CXL protocol CFG
    DWC_cxl_rxdl_llctrl_if.master_mp                        b_rxdl_llctrl           // Receiver link layer interface to link layer control

  , input                                                   cxl_pl_block_dl_init   // Disable Link Layer initialization

  , input ras_dp_err_inj_t                                  ras_dp_err_inj          // RASDP Error Injection control
  , output ras_dp_err_log_t                                 ras_dp_err_log          // RASDP Error Log
  , output [CXL_RX_CORE_RAS_UNCORR_NUM-1:0]                 ras_dp_uncorr_err       // RASDP Uncorr Error to trigger Viral
  , input                                                   cxl_rx_link_disable     // RX Link Disable Request - flush RX Buffers
  , input                                                   cxl_rx_active_req       // RX Activation Request
  , output                                                  cxl_rx_active_sts       // RX Activation Status
  , DWC_cxl_app_ch_init_if.master_mp                        b_app_cache_init
  , DWC_cxl_app_ch_init_if.master_mp                        b_app_mem_init
  , DWC_cxl_app_ch_if.master_device_mp                      b_app_dev_chi           // Application Host Channel Interface
  , DWC_cxl_app_ch_if.master_host_mp                        b_app_host_chi          // Application Device Channel Interface

    ,
    DWC_cxl_ram2p_if.master_mp                              b_cxl_mst_hreq_drsp_ram [0:HREQ_DRSP_NUM-1] ,
    DWC_cxl_ram2p_if.master_mp                              b_cxl_mst_hrsp_dreq_ram [0:HRSP_DREQ_NUM-1] ,
    DWC_cxl_ram2p_if.master_mp                              b_cxl_mst_hd_data_ram [0:HD_DDATA_NUM-1] 

    ,
    DWC_cxl_ram2p_if.master_mp                              b_cxl_mst_ms_ndr_ram [0:MS_SM_NDR_NUM-1 ] ,
    DWC_cxl_ram2p_if.master_mp                              b_cxl_mst_ms_data_ram [0:MS_SM_DDATA_NUM-1 ]
    ,DWC_cxl_ram2p_if.master_mp                             b_cxl_mst_mrsp_ssnp_bi_ram [0:MS_BI_NUM-1]
    ,
    output logic [(CX_CXL_RX_TL_VALID_ERR_WD-1):0]          cxl_rx_dltl_ras_valid_err
    , output                                                cxl_ras_cache_poison               // RAS - CXL.cache Poisoned Data Received
    , output                                                cxl_ras_mem_poison                 // RAS - CXL.mem Poisoned Data Received
    , output logic                                          cxl_rx_crc_error_hit               // RAS - CXL Receiver CRC Error thresold Hit
    , output logic                                          cxl_rx_rsvd_enc_error              // RAS - CXL Receiver Slot Reserved Fields Encoding Violation
    , output logic [7:0]                                    cxl_rx_fifo_ovflw                  // RAS - CXL Receiver FIFO Overflow
    , output logic [(CX_CXL_RX_TL_PTR_ERR_WD-1):0]          cxl_rx_tl_fifo_data_out_ptr_err    // RAS - CXL Receiver FIFO Pointer Error
    , output                                                cxl_rx_mdh_error                   // RAS - Multi-Data Header received when MDH is disabled
    , output logic                                          cxl_rx_tl_pending                  // RX TL Pending Transaction Indication
    , output logic [CXL_DATA_WD-1:0]                        cxl_rx_flit_data                   // Receiver Data Flit
    , output logic [CXL_DATA_PROT_WD-1:0]                   cxl_rx_flit_data_chk               // Receiver Data Parity
);

  logic                                             cxl_rx_dl_idle         ; // CXL RX Data Link Layer Idle

// -------------------------------------------------------------------------------------
// Data Link Layer <-> RASDP Wrapper <-> Transaction Layer Interfaces
// -------------------------------------------------------------------------------------
DWC_cxl_rxtl_llctrl_if                              b_rxll_llctrl ()       ; // Link Layer Interface to RASDP Wrapper 
DWC_cxl_rxtl_llctrl_if                              b_rxtl_llctrl ()       ; // RASDP Wrapper to Transaction Layer Interface
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// RASDP Wrapper 2 Transaction Layer Connections
// -------------------------------------------------------------------------------------
  logic                                             cxl_rx_flit_crc_error    ;

  logic [CACHE_REQ_VALID_WD-1:0]                    cxl_rx_tl_cache_req_valid;
  logic [CACHE_RSP_VALID_WD-1:0]                    cxl_rx_tl_cache_rsp_valid;
  logic [HD_DDATA_NUM - 1: 0]                       cxl_rx_tl_cache_data_valid;
  logic                                             cxl_dltl_h2d_crc_err     ;
  assign cxl_dltl_h2d_crc_err  =      cxl_rx_flit_crc_error;
  logic                                             cxl_dltl_d2h_crc_err     ;
  assign cxl_dltl_d2h_crc_err  =      cxl_rx_flit_crc_error;

  logic [(MEM_NDR_VALID_WD-1)  : 0]                 cxl_rx_tl_mem_ndr_valid  ;
  logic [MS_SM_DDATA_NUM - 1: 0]                    cxl_rx_tl_mem_data_valid ;
  logic [MEM_BI_VALID_WD-1:0]                       cxl_rx_tl_mem_bi_valid   ;
  logic                                             cxl_dltl_m2s_crc_err;
  assign cxl_dltl_m2s_crc_err  =      cxl_rx_flit_crc_error;
  logic                                             cxl_dltl_s2m_crc_err;
  assign cxl_dltl_s2m_crc_err  =      cxl_rx_flit_crc_error;


// -------------------------------------------------------------------------------------


localparam CXL_TX_RAS_ERR_LOG_NUM = 1;

ras_dp_err_inj_t                                  ras_dp_err_inj_rx;    // Error injection for CXL RX checkers

ras_dp_err_log_t                                  ras_dp_err_log_dl;    // Error Logs from Link Layer
ras_dp_err_log_t [CXL_TX_RAS_ERR_LOG_NUM-1:0]     ras_dp_err_log_arr;   // Error logs from both TL and LL

assign ras_dp_err_log_arr = ras_dp_err_log_dl;

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( CXL_TX_RAS_ERR_LOG_NUM )
) u_cxl_tx_ras_dp_err_mgr (
    .clk                ( b_clk.s_core_clk            ),
    .rst_n              ( b_clk.s_core_rst_n          ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj              ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_rx           ),
    .in_ras_dp_err_log  ( ras_dp_err_log_arr          ),
    .out_ras_dp_err_log ( ras_dp_err_log              )
);



// -------------------------------------------------------------------------------------
// CXL RX Data Link Layer Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rx_dl
 U_DWC_cxl_mem_cache_rx_dl (
         .core_clk                              (b_clk.s_core_clk                      )
        ,.core_rst_n                            (b_clk.s_core_rst_n                    )
        ,.cxl_protocol_cfg                      (cxl_protocol_cfg                      )
        ,.b_cdm                                 (b_cdm                                 )
        ,.b_arb_llctrl                          (b_arb_llctrl                          )
        ,.b_rxdl_llctrl                         (b_rxdl_llctrl                         )
        ,.cxl_pl_block_dl_init                  (cxl_pl_block_dl_init                  )
        ,.ras_dp_err_inj                        (ras_dp_err_inj_rx                     )
        ,.ras_dp_err_log                        (ras_dp_err_log_dl                     )
        ,.ras_dp_uncorr_err                     (ras_dp_uncorr_err                     )
        ,.b_rxtl_llctrl                         (b_rxll_llctrl.master_mp               )
        ,.cxl_rx_tl_cache_req_valid             (cxl_rx_tl_cache_req_valid             )
        ,.cxl_rx_tl_cache_rsp_valid             (cxl_rx_tl_cache_rsp_valid             )
        ,.cxl_rx_tl_cache_data_valid            (cxl_rx_tl_cache_data_valid            )
        ,.cxl_rx_tl_mem_ndr_valid               (cxl_rx_tl_mem_ndr_valid               )
        ,.cxl_rx_tl_mem_data_valid              (cxl_rx_tl_mem_data_valid              )
        ,.cxl_rx_tl_mem_bi_valid                (cxl_rx_tl_mem_bi_valid                )
       ,.cxl_rx_mdh_error                       (cxl_rx_mdh_error                      )
       ,.cxl_rx_crc_error                       (cxl_rx_flit_crc_error                 )
       ,.cxl_ras_cache_poison                   (cxl_ras_cache_poison                  )
       ,.cxl_ras_mem_poison                     (cxl_ras_mem_poison                    )
       ,.cxl_rx_crc_error_hit                   (cxl_rx_crc_error_hit                  )
       ,.cxl_rx_rsvd_enc_error                  (cxl_rx_rsvd_enc_error                 )
       ,.cxl_rx_dl_idle                         (cxl_rx_dl_idle                        )
       ,.cxl_rx_flit_data                       (cxl_rx_flit_data                      )
       ,.cxl_rx_flit_data_chk                   (cxl_rx_flit_data_chk                  )
); // DWC_cxl_mem_cache_rx_dl

// -------------------------------------------------------------------------------------
// CXL RX RASDP Wrapper Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rx_rasdp_wr_ms
 u_rx_rasdp_wr (
         .core_clk                                     (b_clk.s_core_clk                              )
        ,.core_rst_n                                   (b_clk.s_core_rst_n                            )
        ,.b_rxdl_llctrl                                (b_rxll_llctrl.slave_mp                        )
        ,.b_rxtl_llctrl                                (b_rxtl_llctrl.master_rasdp_mp                 )
); // DWC_cxl_mem_cache_rx_rasdp_wr

// -------------------------------------------------------------------------------------
// CXL RX Transaction Layer Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rx_tl
 U_DWC_cxl_mem_cache_rx_tl(
         .b_clk                             (b_clk                              )
        ,.b_rxtl_llctrl                     (b_rxtl_llctrl.rxtl_integrated_rasdp_mp       )
        ,.cxl_rx_link_disable               (cxl_rx_link_disable                )
        ,.cxl_rx_active_req                 (cxl_rx_active_req                  )
        ,.cxl_rx_active_sts                 (cxl_rx_active_sts                  )
        ,.cxl_rx_dltl_ras_valid_err         (cxl_rx_dltl_ras_valid_err          )
        ,.cxl_rx_tl_fifo_data_out_ptr_err   (cxl_rx_tl_fifo_data_out_ptr_err    )
        ,.cxl_device_mode                   (b_cdm.s_cfg_dev_mode               )
        ,.cxl_rx_dl_idle                    (cxl_rx_dl_idle                     )
        ,.cxl_rx_tl_pending                 (cxl_rx_tl_pending                  )
        ,.b_app_cache_init                  ( b_app_cache_init                  )
        ,.b_app_mem_init                    ( b_app_mem_init                    )
        ,.b_app_host_chi                    ( b_app_host_chi                    )
        ,.b_app_dev_chi                     ( b_app_dev_chi                     )

        ,.cxl_rx_fifo_ovflw                 (cxl_rx_fifo_ovflw                  )
        ,.cxl_rx_tl_cache_req_valid         (cxl_rx_tl_cache_req_valid          )
        ,.cxl_rx_tl_cache_rsp_valid         (cxl_rx_tl_cache_rsp_valid          )
        ,.cxl_rx_tl_cache_data_valid        (cxl_rx_tl_cache_data_valid         )
        ,.b_cxl_mst_hreq_drsp_ram           (b_cxl_mst_hreq_drsp_ram            )
        ,.b_cxl_mst_hrsp_dreq_ram           (b_cxl_mst_hrsp_dreq_ram            )
        ,.b_cxl_mst_hd_data_ram             (b_cxl_mst_hd_data_ram              )
        ,.cxl_dltl_h2d_crc_err              (cxl_dltl_h2d_crc_err               )
        ,.cxl_dltl_d2h_crc_err              (cxl_dltl_d2h_crc_err               )
        ,.cxl_rx_tl_mem_ndr_valid           (cxl_rx_tl_mem_ndr_valid            )
        ,.cxl_rx_tl_mem_data_valid          (cxl_rx_tl_mem_data_valid           )
        ,.b_cxl_mst_ms_ndr_ram              (b_cxl_mst_ms_ndr_ram               )
        ,.b_cxl_mst_ms_data_ram             (b_cxl_mst_ms_data_ram              )
        ,.cxl_dltl_m2s_crc_err              (cxl_dltl_m2s_crc_err               )
        ,.cxl_dltl_s2m_crc_err              (cxl_dltl_s2m_crc_err               )
        ,.cxl_rx_tl_mem_bi_valid            (cxl_rx_tl_mem_bi_valid             )
        ,.b_cxl_mst_mrsp_ssnp_bi_ram        (b_cxl_mst_mrsp_ssnp_bi_ram         )
); // DWC_cxl_mem_cache_rx_tl


endmodule
