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
// ---   $DateTime: 2024/02/09 07:28:50 $
// ---   $Revision: #25 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_core.sv#25 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Controller Top Module
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_cdmregs_if.svh"
`include "CXL/svif/DWC_cxl_rxdl_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_arb_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_rbuf_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_app_ch_init_if.svh"
`include "CXL/svif/DWC_cxl_app_ch_if.svh"
`include "CXL/svif/DWC_cxl_ram2p_if.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
module DWC_cxl_mem_cache_core
    import spif_pkg::protocol_cfg_t;
    import spif_pkg::state_enc_e;
    import spif_pkg::DISABLED;
    import spif_pkg::LINKRESET;
    import spif_pkg::LINKERROR;
    import spif_pkg::SID_CXL_CM;
    import DWC_cxl_pkg::*;
    import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
    import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
#(
    parameter TP = `TP
) 
                                 (
    DWC_cxl_clk_rst_if.slave_mp                      b_clk                   ,  // Clock and reset interface
    DWC_cxl_cdmregs_if.slave_cdm_mp                  b_cxl_cdm               ,  // CDM interface
    // -------------------------------------------------------------------------------------
    // CXL Transmitter Link Layer Controller Interfaces
    // -------------------------------------------------------------------------------------
    spif_if.slave_mp                                 b_vlsm_llctrl           ,  // Link Layer to VLSM SPIF Interface for CXL.cachemem
    spif_if.cfgi_master_mp                           b_cfgi_lbc              ,  // CFGI SPIF interface
    DWC_cxl_rbuf_llctrl_if.master_mp                 b_rbuf_llctrl           ,  // Retry Buffer Interface
    // -------------------------------------------------------------------------------------
    // Protocol Configuration Structure
    // -------------------------------------------------------------------------------------
    output protocol_cfg_t                            cxl_protocol_cfg        ,  // Protocol Configuration for CXL Controller
    // -------------------------------------------------------------------------------------
    // PM Controller Interface
    // -------------------------------------------------------------------------------------
    output                                           cxl_link_tx_deinit_req  ,  // Tx Link deinit for app interface 
    input                                            lp_cxl_l1_exit          ,  // SPIF: Request to CXL.cachemem Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
    input                                            lp_cxl_clk_ack          ,  // SPIF: CXL.cachemem Link Layer acknowledges LogPHY request to remove the clock gating
    input                                            lp_cxl_wake_req         ,  // SPIF: CXL.cachemem Link Layer requests LogPHY to remove the clock gating
    input                                            pm_req_l2                  // PM request L2 Entry from PM Controller
    ,
    // -------------------------------------------------------------------------------------
    // CXL Message Channel Interface
    // -------------------------------------------------------------------------------------
    DWC_cxl_app_ch_init_if.slave_mp                  b_app_cache_tx_init     ,  // Transmitter CXL.cache Message Channel Initialization Interface
    DWC_cxl_app_ch_init_if.master_mp                 b_app_cache_rx_init     ,  // Receiver CXL.cache Message Channel Initialization Interface
    DWC_cxl_app_ch_init_if.slave_mp                  b_app_mem_tx_init       ,  // Transmitter CXL.mem Message Channel Initialization Interface
    DWC_cxl_app_ch_init_if.master_mp                 b_app_mem_rx_init       ,  // Receiver CXL.mem Message Channel Initialization Interface
    DWC_cxl_app_ch_if.slave_device_mp                b_app_dev_tx_chi        ,  // Endpoint TX D2H and S2M message channel interface
    DWC_cxl_app_ch_if.master_host_mp                 b_app_host_rx_chi       ,  // Endpoint RX H2D and M2S message channel interface
    DWC_cxl_app_ch_if.slave_host_mp                  b_app_host_tx_chi       ,  // Root Complex TX H2D and M2S message channel interfaces
    DWC_cxl_app_ch_if.master_device_mp               b_app_dev_rx_chi        ,  // Root Complex RX D2H and S2M message channel interface
    // -------------------------------------------------------------------------------------
    // CXL Application Viral Interface
    // -------------------------------------------------------------------------------------
    input                                            cxl_viral_request         // Viral Mode request from the Application
    // -------------------------------------------------------------------------------------
    // CXL RAS Stat Interface
    // -------------------------------------------------------------------------------------
    ,
    input [1:0]                                      cxl_ras_stat_rx_corr    ,  // Correctable Error from RASDP Glue Logic
    input [7:0]                                      cxl_ras_stat_rx_uncorr  ,  // Uncorrectable Error from RASDP Glue Logic
    input [CXL_RAS_HDR_LOG_SIZE-1:0]                 cxl_ras_stat_rx_hdr_log    // Header Log from RASDP Glue Logic
    ,
    // --------------------------------------------------------------------------------------
    // CXL Device Rx Cache Message Channel memory interfaces
    // --------------------------------------------------------------------------------------
    DWC_cxl_ram2p_if.master_mp                       b_cxl_mst_hreq_drsp_ram  [0:HREQ_DRSP_NUM-1 ] ,
    DWC_cxl_ram2p_if.master_mp                       b_cxl_mst_hrsp_dreq_ram [0:HRSP_DREQ_NUM-1] ,
    DWC_cxl_ram2p_if.master_mp                       b_cxl_mst_hd_data_ram [0:HD_DDATA_NUM-1]
    ,
    // --------------------------------------------------------------------------------------
    // CXL Device Rx Mem Message Channel memory interfaces
    // --------------------------------------------------------------------------------------
    DWC_cxl_ram2p_if.master_mp                       b_cxl_mst_ms_ndr_ram [0:MS_SM_NDR_NUM-1 ] ,
    DWC_cxl_ram2p_if.master_mp                       b_cxl_mst_ms_data_ram [0:MS_SM_DDATA_NUM-1 ]
    ,
    // --------------------------------------------------------------------------------------
    // CXL Device Rx Mem Back-Invalidate Channel memory interfaces
    // --------------------------------------------------------------------------------------
    DWC_cxl_ram2p_if.master_mp                       b_cxl_mst_mrsp_ssnp_bi_ram [0:MS_BI_NUM-1 ]
    ,output                              cxl_s2m_data_pis 
    ,output                              cxl_m2s_data_pis 
    ,output                              cxl_h2d_data_pis 
    ,output                              cxl_d2h_data_pis 
);
  // Mis-sampling delay for quasi static signals
  localparam CC_MIS_SAMPLING_DELAY = 3;

  // Number of RAS DP Error Logs to be connected to RAS DP Top-level Manager
  localparam CXL_RAS_ERR_LOG_NUM = 2;

// Interfaces
DWC_cxl_cdmregs_if                     b_rx_cdm();              // Receiver CDM interface
DWC_cxl_cdmregs_if                     b_tx_cdm();              // Transmitter CDM interface
DWC_cxl_rxdl_llctrl_if                 b_rxdl_llctrl ();        // Receiver link layer interface to link layer control
// Registers & Wires
wire                                   cfg_dev_mode_s;          // Configuration Device Mode: 0 (Device), 1 (Host)
wire                                   cxl_rx_tl_pending;       // Indicates that transaction are pending in the Receive Buffers
wire                                   ll_reset_clr_s;          // Clear LL Reset flag in CXL LL Control and Status Register
wire [31:0]                            cxl_fatal_error_s;       // CXL Controller Fatal Error Bus
wire [16:0]                            ras_uncorr_sts_s;        // Uncorrectable Error Status Register
wire [6:0]                             ras_corr_sts_s;          // Correctable Error Status Register
wire [511:0]                           ras_header_log_s;        // RAS Header Log Register
wire [7:0]                             cxl_tx_fifo_ovflw_s;     // RAS - CXL Transmitter Channel Message FIFO Overflow
wire [7:0]                             cxl_rx_fifo_ovflw_s;     // RAS - CXL Receiver FIFO Overflow
wire [CX_CXL_RX_TL_PTR_ERR_WD-1:0]     cxl_rx_fifo_ptr_err_s;   // RAS - CXL Receiver FIFO Pointer Error
wire                                   cxl_rx_mdh_error_s;      // RAS - Multi-Data Header received when MDH is disabled
wire                                   cxl_rx_crc_error_hit_s;  // RAS - CXL Receiver CRC Error thresold Hit
wire                                   cxl_rx_rsvd_enc_error_s; // RAS - CXL Receiver Slot Reserved Fields Encoding Violation
wire [CXL_DATA_WD-1:0]                 cxl_rx_flit_data_s;      // RAS - CXL Receiver Data Flit
wire [CXL_DATA_PROT_WD-1:0]            cxl_rx_flit_data_chk_s;  // RAS - CXL Receiver Data Flit Protection
wire                                   cxl_rx_cache_poison_s;   // RAS - CXL.cache Poisoned Data Received
wire                                   cxl_rx_mem_poison_s;     // RAS - CXL.mem Poisoned Data Received
wire [CX_CXL_RX_TL_VALID_ERR_WD-1:0]   s_ras_stat_cxl_vld_err;  // RASDP - CXL Receiver Valid Bit Error

wire [MAX_RETRY_WD-1:0]                max_num_retry_s;
wire [MAX_REINIT_WD-1:0]               max_num_reinit_s;
wire [RETRY_TIMER_WD-1:0]              lrsm_timeout_threshold_s;
wire [MAX_RX_CRC_ERROR_WD-1:0]         crc_threshold_s;
wire                                   cxl_link_disable;
wire                                   cxl_rx_active_sts;  // SPIF Interface RX Activation Status


ras_dp_err_inj_t                            ras_dp_err_inj_s;   // Error Injection control to CXL RASDP checkers

ras_dp_err_log_t                            ras_dp_err_log_tx;          // Error Logs from CXL TX RASDP checkers
ras_dp_err_log_t                            ras_dp_err_log_rx;          // Error Logs from CXL RX RASDP checkers
ras_dp_err_log_t [CXL_RAS_ERR_LOG_NUM-1:0]  ras_dp_err_log_cxl;         // Error Logs from all CXL checkers

logic [CXL_RX_CORE_RAS_UNCORR_NUM-1:0]      ras_dp_uncorr_err_rx_core;  // Uncorrectable Errors from CXL Core RX RASDP checkers
logic [CXL_RX_RAS_UNCORR_NUM-1:0]           ras_dp_uncorr_err_rx;       // Uncorrectable Errors from CXL RX checkers
logic [CXL_TX_RAS_UNCORR_NUM-1:0]           ras_dp_uncorr_err_tx;       // Uncorrectable Errors from CXL Core TX RASDP checkers

assign ras_dp_err_log_cxl = {ras_dp_err_log_tx, ras_dp_err_log_rx};
assign ras_dp_uncorr_err_rx = {ras_dp_uncorr_err_rx_core};

// -------------------------------------------------------------------------------------
// CXL CDM Interface Membar0 Connections
// -------------------------------------------------------------------------------------
assign b_cxl_cdm.s_mbar0_ras_unc_cache_data_parity        = ras_uncorr_sts_s[0];
assign b_cxl_cdm.s_mbar0_ras_unc_cache_addr_parity        = ras_uncorr_sts_s[1];
assign b_cxl_cdm.s_mbar0_ras_unc_cache_be_parity          = ras_uncorr_sts_s[2];
assign b_cxl_cdm.s_mbar0_ras_unc_cache_data_ecc           = ras_uncorr_sts_s[3];
assign b_cxl_cdm.s_mbar0_ras_unc_mem_data_parity          = ras_uncorr_sts_s[4];
assign b_cxl_cdm.s_mbar0_ras_unc_mem_addr_parity          = ras_uncorr_sts_s[5];
assign b_cxl_cdm.s_mbar0_ras_unc_mem_be_parity            = ras_uncorr_sts_s[6];
assign b_cxl_cdm.s_mbar0_ras_unc_mem_data_ecc             = ras_uncorr_sts_s[7];
assign b_cxl_cdm.s_mbar0_ras_unc_reinit_threshold         = ras_uncorr_sts_s[8];
assign b_cxl_cdm.s_mbar0_ras_unc_rsvd_encoding_violation  = ras_uncorr_sts_s[9];
assign b_cxl_cdm.s_mbar0_ras_unc_poison_received          = ras_uncorr_sts_s[10];
assign b_cxl_cdm.s_mbar0_ras_unc_receiver_overflow        = ras_uncorr_sts_s[11];
assign b_cxl_cdm.s_mbar0_ras_unc_internal_error           = ras_uncorr_sts_s[14];
assign b_cxl_cdm.s_mbar0_ras_unc_cxl_ide_tx_error         = ras_uncorr_sts_s[15];
assign b_cxl_cdm.s_mbar0_ras_unc_cxl_ide_rx_error         = ras_uncorr_sts_s[16];
assign b_cxl_cdm.s_mbar0_ras_corr_cache_data_ecc          = ras_corr_sts_s[0];
assign b_cxl_cdm.s_mbar0_ras_corr_mem_data_ecc            = ras_corr_sts_s[1];
assign b_cxl_cdm.s_mbar0_ras_corr_crc_threshold           = ras_corr_sts_s[2];
assign b_cxl_cdm.s_mbar0_ras_corr_retry_threshold         = ras_corr_sts_s[3];
assign b_cxl_cdm.s_mbar0_ras_corr_cache_poison_received   = ras_corr_sts_s[4];
assign b_cxl_cdm.s_mbar0_ras_corr_mem_poison_received     = ras_corr_sts_s[5];
assign b_cxl_cdm.s_mbar0_ras_corr_physical_layer_error    = ras_corr_sts_s[6];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg0              = ras_header_log_s[31:0];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg1              = ras_header_log_s[63:32];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg2              = ras_header_log_s[95:64];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg3              = ras_header_log_s[127:96];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg4              = ras_header_log_s[159:128];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg5              = ras_header_log_s[191:160];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg6              = ras_header_log_s[223:192];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg7              = ras_header_log_s[255:224];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg8              = ras_header_log_s[287:256];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg9              = ras_header_log_s[319:288];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg10             = ras_header_log_s[351:320];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg11             = ras_header_log_s[383:352];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg12             = ras_header_log_s[415:384];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg13             = ras_header_log_s[447:416];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg14             = ras_header_log_s[479:448];
assign b_cxl_cdm.s_mbar0_ras_header_log_reg15             = ras_header_log_s[511:480];
assign b_cxl_cdm.s_mbar0_link_ver_received                = b_rx_cdm.s_cxl_rx_rcvd_init_cxl_version;
assign b_cxl_cdm.s_mbar0_link_llr_wrap_val_received       = b_rx_cdm.s_cxl_rx_rcvd_init_llr_wrap_value;
assign b_cxl_cdm.s_mbar0_link_num_retry_received          = b_rx_cdm.s_cxl_rx_rcvd_retry_req_num_retry;
assign b_cxl_cdm.s_mbar0_link_num_phy_reinit_received     = b_rx_cdm.s_cxl_rx_rcvd_retry_req_num_phy_reinit;
assign b_cxl_cdm.s_mbar0_link_wr_ptr_received             = b_rx_cdm.s_cxl_rx_retry_ack_wrptr;
assign b_cxl_cdm.s_mbar0_link_echo_eseq_received          = b_rx_cdm.s_cxl_rx_retry_ack_eseq;
assign b_cxl_cdm.s_mbar0_link_num_free_buf_received       = b_rx_cdm.s_cxl_rx_retry_ack_numfreebuf;
assign b_cxl_cdm.s_mbar0_link_ll_reset_clr                = ll_reset_clr_s;
assign b_cxl_cdm.s_mbar0_link_init_state                  = b_tx_cdm.s_cfg_ll_init_state;
assign b_cxl_cdm.s_mbar0_link_ll_retry_buffer_consumed    = { {(8-RBUF_ADD_WD){1'b0}}, b_tx_cdm.s_cfg_ll_rbuf_consumed };
assign b_cxl_cdm.s_mbar0_link_tx_cache_req_credits_stat   = { {(10-TX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_tx_cache_req_credits };
assign b_cxl_cdm.s_mbar0_link_tx_cache_rsp_credits_stat   = { {(10-TX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_tx_cache_rsp_credits };
assign b_cxl_cdm.s_mbar0_link_tx_cache_data_credits_stat  = { {(10-TX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_tx_cache_data_credits };
assign b_cxl_cdm.s_mbar0_link_rx_cache_req_credits_stat   = { {(10-RX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_rx_cache_req_crdrets };
assign b_cxl_cdm.s_mbar0_link_rx_cache_rsp_credits_stat   = { {(10-RX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_rx_cache_rsp_crdrets };
assign b_cxl_cdm.s_mbar0_link_rx_cache_data_credits_stat  = { {(10-RX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_rx_cache_data_crdrets };
assign b_cxl_cdm.s_mbar0_link_tx_mem_req_rsp_credits_stat = { {(10-TX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_tx_mem_req_rsp_credits };
assign b_cxl_cdm.s_mbar0_link_tx_mem_data_credits_stat    = { {(10-TX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_tx_mem_data_credits };

assign b_cxl_cdm.s_mbar0_link_rx_mem_req_rsp_credits_stat = { {(10-RX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_rx_mem_req_rsp_crdrets };
assign b_cxl_cdm.s_mbar0_link_rx_mem_data_credits_stat    = { {(10-RX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_rx_mem_data_crdrets };
    
assign b_cxl_cdm.s_mbar0_link_tx_mem_bi_credits_stat      = { {(10-RX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_tx_mem_bi_credits };
assign b_cxl_cdm.s_mbar0_link_rx_mem_bi_credits_stat      = { {(10-RX_CREDIT_WD){1'b0}}, b_tx_cdm.s_cfg_rx_mem_bi_crdrets };

  

// -------------------------------------------------------------------------------------
// CXL CDM Interface Port Reg Connections
// -------------------------------------------------------------------------------------
// CXL Fatal Error Register
assign b_cxl_cdm.s_pl_reg_fatal_error          = cxl_fatal_error_s;
// CXL LRSM Control and Status Register (CXL_LRSM_CSR)
assign b_cxl_cdm.s_pl_reg_lrsm_state           = {1'b0, b_tx_cdm.s_lrsm_state};
assign b_cxl_cdm.s_pl_reg_lrsm_fatal_error     = b_tx_cdm.s_lrsm_uc_err;

// -------------------------------------------------------------------------------------
// Transmitter CDM Interface Connections
// -------------------------------------------------------------------------------------
assign b_tx_cdm.s_cfg_dev_mode            = b_vlsm_llctrl.s_pl_device_port;
assign b_tx_cdm.s_cfg_viral_status        = b_cxl_cdm.s_cfg_cxl_viral_status   ;
assign b_tx_cdm.s_cfg_ll_reset            = b_cxl_cdm.s_mbar0_link_ll_reset      ;
assign b_tx_cdm.s_cfg_ll_init_stall       = b_cxl_cdm.s_mbar0_link_ll_init_stall ;
assign b_tx_cdm.s_cfg_ll_crd_stall        = b_cxl_cdm.s_mbar0_link_ll_crd_stall  ;
assign b_tx_cdm.s_cfg_ack_force_threshold = b_cxl_cdm.s_mbar0_link_ack_force_threshold ;
assign b_tx_cdm.s_cfg_ack_flush_timer     = b_cxl_cdm.s_mbar0_link_ack_flush_retimer   ;
assign b_tx_cdm.s_cfg_llr_wrap_value      = b_cxl_cdm.s_mbar0_link_llr_wrap_val_supported;
assign b_tx_cdm.s_cfg_cxl_version         = b_cxl_cdm.s_mbar0_link_ver_supported;
assign b_tx_cdm.s_cfg_max_retry           = max_num_retry_s;             // PROGRAMMED VIA CXL LRSM Control and Status Register (CXL_LRSM_CSR)
assign b_tx_cdm.s_cfg_max_reinit          = max_num_reinit_s;            // PROGRAMMED VIA CXL LRSM Control and Status Register (CXL_LRSM_CSR)
assign b_tx_cdm.s_cfg_retry_timer         = lrsm_timeout_threshold_s;    // PROGRAMMED VIA CXL LRSM Timeout Control Register (CXL_LRSM_TIMEOUT_CR)
assign b_tx_cdm.s_cfg_rx_rcvd_llr_wrap    = b_rx_cdm.s_cxl_rx_rcvd_init_llr_wrap_value;
assign b_tx_cdm.s_cfg_cxl_mdh_disable     = b_cxl_cdm.s_mbar0_link_mdh_disable   ;
assign b_tx_cdm.s_cfg_rx_cache_req_credits  = b_cxl_cdm.s_mbar0_link_rx_cache_req_credits[RX_CREDIT_WD-1:0];
assign b_tx_cdm.s_cfg_rx_cache_rsp_credits  = b_cxl_cdm.s_mbar0_link_rx_cache_rsp_credits[RX_CREDIT_WD-1:0];
assign b_tx_cdm.s_cfg_rx_cache_data_credits = b_cxl_cdm.s_mbar0_link_rx_cache_data_credits[RX_CREDIT_WD-1:0];
assign b_tx_cdm.s_cfg_rx_mem_ndr_credits    = b_cxl_cdm.s_mbar0_link_rx_mem_req_rsp_credits[RX_CREDIT_WD-1:0];
assign b_tx_cdm.s_cfg_rx_mem_data_credits   = b_cxl_cdm.s_mbar0_link_rx_mem_data_credits[RX_CREDIT_WD-1:0];
assign b_tx_cdm.s_cfg_rx_mem_bi_credits   = b_cxl_cdm.s_mbar0_link_rx_mem_bi_credits[RX_CREDIT_WD-1:0];
assign b_tx_cdm.s_cfg_mc_crc_err_inj      = b_cxl_cdm.s_pl_reg_cm_ll_cache_mem_crc_injection;
assign b_tx_cdm.s_cfg_mc_crc_err_inj_cnt  = b_cxl_cdm.s_pl_reg_cm_ll_cache_mem_crc_injection_count;
assign b_cxl_cdm.s_pl_reg_cm_ll_cache_mem_crc_injection_busy = b_tx_cdm.s_cfg_mc_crc_err_inj_busy;
assign b_tx_cdm.s_cfg_cache_poison_start  = b_cxl_cdm.s_pl_reg_cm_ll_cache_poison_injection_start;
assign b_cxl_cdm.s_pl_reg_cm_ll_cache_poison_injection_busy = b_tx_cdm.s_cfg_cache_poison_busy;
assign b_tx_cdm.s_cfg_mem_poison_start    = b_cxl_cdm.s_pl_reg_cm_ll_mem_poison_injection_start;
assign b_cxl_cdm.s_pl_reg_cm_ll_mem_poison_injection_busy = b_tx_cdm.s_cfg_mem_poison_busy;
// -------------------------------------------------------------------------------------
// Receiver CDM Interface Connections
// -------------------------------------------------------------------------------------
assign b_rx_cdm.s_cfg_dev_mode            = b_vlsm_llctrl.s_pl_device_port;
assign b_rx_cdm.s_cfg_cxl_mdh_disable     = b_cxl_cdm.s_mbar0_link_mdh_disable;
assign b_rx_cdm.s_cxl_rx_max_crc_error    = crc_threshold_s;

// Flush all transactions and disable Link Layer as a part of graceful reset flow
assign cxl_link_disable                   = (b_vlsm_llctrl.s_pl_state_sts inside {DISABLED, LINKRESET, LINKERROR});


// -------------------------------------------------------------------------------------
// CXL Device Mode
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Reset Flag to clear LL Reset bit in CXL Link Layer Control and Status Register
// -------------------------------------------------------------------------------------
delay_n
 #(
    .N          ( 1                     ),
    .WD         ( 1                     ),
    .RESETVAL   ( 1'b1                  )
) u_delay_ll_rst_clr (
    .clk        ( b_clk.s_core_clk      ),
    .rst_n      ( b_clk.s_core_rst_n    ),
    .clear      ( 1'b0                  ),
    .din        ( 1'b0                  ),
    .dout       ( ll_reset_clr_s        )
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Input registers on signals from CDM
// This is to improve timing on some paths from CDM
// -------------------------------------------------------------------------------------
delay_n
 #(
    .N          ( 1                                ),
    .WD         ( MAX_RETRY_WD                     ),
    .RESETVAL   ( 'hA                              )
) u_delay_max_num_retry (
    .clk        ( b_clk.s_core_clk                 ),
    .rst_n      ( b_clk.s_core_rst_n               ),
    .clear      ( 1'b0                             ),
    .din        ( b_cxl_cdm.s_pl_reg_max_num_retry ),
    .dout       ( max_num_retry_s                  )
);

delay_n
 #(
    .N          ( 1                                 ),
    .WD         ( MAX_REINIT_WD                     ),
    .RESETVAL   ( 'hA                               )
) u_delay_max_num_reinit (
    .clk        ( b_clk.s_core_clk                  ),
    .rst_n      ( b_clk.s_core_rst_n                ),
    .clear      ( 1'b0                              ),
    .din        ( b_cxl_cdm.s_pl_reg_max_num_reinit ),
    .dout       ( max_num_reinit_s                  )
);

delay_n
 #(
    .N          ( 1                                         ),
    .WD         ( RETRY_TIMER_WD                            ),
    .RESETVAL   ( 'd4096                                    )
) u_delay_lrsm_timeout_threshold (
    .clk        ( b_clk.s_core_clk                          ),
    .rst_n      ( b_clk.s_core_rst_n                        ),
    .clear      ( 1'b0                                      ),
    .din        ( b_cxl_cdm.s_pl_reg_lrsm_timeout_threshold ),
    .dout       ( lrsm_timeout_threshold_s                  )
);

delay_n
 #(
    .N          ( 1                                ),
    .WD         ( MAX_RX_CRC_ERROR_WD              ),
    .RESETVAL   ( 'h1                              )
) u_delay_crc_threshold (
    .clk        ( b_clk.s_core_clk                 ),
    .rst_n      ( b_clk.s_core_rst_n               ),
    .clear      ( 1'b0                             ),
    .din        ( b_cxl_cdm.s_pl_reg_crc_threshold ),
    .dout       ( crc_threshold_s                  )
);
// -------------------------------------------------------------------------------------





// -------------------------------------------------------------------------------------
// RASDP Error Manager for Multi-Stream Architecture
// -------------------------------------------------------------------------------------
ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( CXL_RAS_ERR_LOG_NUM )
) u_ras_dp_err_mgr (
    .clk                ( b_clk.s_core_clk           ),
    .rst_n              ( b_clk.s_core_rst_n         ),
    .in_ras_dp_err_inj  ( b_cxl_cdm.s_ras_dp_err_inj ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_s           ),
    .in_ras_dp_err_log  ( ras_dp_err_log_cxl         ),
    .out_ras_dp_err_log ( b_cxl_cdm.s_ras_dp_err_log )
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// CXL Transmitter Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_tx
 U_DWC_cxl_mem_cache_tx (
    .b_clk                                  ( b_clk                                      ),
    .b_cdm                                  ( b_tx_cdm.slave_mp                          ),
    .b_rxdl_llctrl                          ( b_rxdl_llctrl.slave_mp                     ),
    .b_vlsm_llctrl                          ( b_vlsm_llctrl                              ),
    .b_cfgi_spif                            ( b_cfgi_lbc                                 ),
    .b_rbuf_llctrl                          ( b_rbuf_llctrl                              ),
    .ras_dp_err_inj                         ( ras_dp_err_inj_s                           ),
    .ras_dp_err_log                         ( ras_dp_err_log_tx                          ),
    .ras_dp_uncorr_err                      ( ras_dp_uncorr_err_tx                       ),
    .cxl_protocol_cfg                       ( cxl_protocol_cfg                           ),
    .b_app_cache_init                       ( b_app_cache_tx_init                        ),
    .b_app_mem_init                         ( b_app_mem_tx_init                          ),
    .b_app_host_chi                         ( b_app_host_tx_chi                          ),
    .b_app_dev_chi                          ( b_app_dev_tx_chi                           ),
    .cxl_tx_fifo_ovflw_o                    ( cxl_tx_fifo_ovflw_s                        ),
    .link_tx_deinit_req                     ( cxl_link_tx_deinit_req                     ),
    .lp_cxl_l1_exit                         ( lp_cxl_l1_exit                             ),
    .lp_cxl_clk_ack                         ( lp_cxl_clk_ack                             ),
    .lp_cxl_wake_req                        ( lp_cxl_wake_req                            ),
    .pm_req_l2                              ( pm_req_l2                                  ),
    .cxl_rx_active_sts                      ( cxl_rx_active_sts                          )
      ,.cxl_s2m_data_pis                    (cxl_s2m_data_pis                            )
      ,.cxl_m2s_data_pis                    (cxl_m2s_data_pis                            ) 
      ,.cxl_h2d_data_pis                    (cxl_h2d_data_pis                            )
      ,.cxl_d2h_data_pis                    (cxl_d2h_data_pis                            )
); // U_DWC_cxl_mem_cache_tx


// -------------------------------------------------------------------------------------
// Align SPIF interface data width to CXL.cachemem Link Layer data width and interface
// on CXL Receiver inputs.
//
// To be moved to the Flit Checker and old interface to be removed!!!
// -------------------------------------------------------------------------------------
spif_if                         b_rplh_spif();      // RPLH SPIF Interface to be mapped on b_smlh_vlsm
DWC_cxl_arb_llctrl_if           b_rx_arb_llctrl();  // ARB/MUX RX link layer control Interface
logic                           rx_buff_flit_valid;
logic [ARBMUX_DATA_WD-1:0]      rx_buff_flit_data;
logic [ARBMUX_DATA_PROT_WD-1:0] rx_buff_flit_data_chk;
logic                           rx_buff_crc_valid;
logic [15:0]                    rx_buff_crc_data;

// RPLH SPIF Interface Connections
assign b_rplh_spif.s_pl_stream        = b_vlsm_llctrl.s_pl_stream        ;
assign b_rplh_spif.s_pl_valid         = b_vlsm_llctrl.s_pl_valid         ;
assign b_rplh_spif.s_pl_data          = b_vlsm_llctrl.s_pl_data          ;
assign b_rplh_spif.s_pl_data_chk      = b_vlsm_llctrl.s_pl_data_chk      ;
assign b_rplh_spif.s_pl_crc_valid     = b_vlsm_llctrl.s_pl_crc_valid     ;
assign b_rplh_spif.s_pl_crc_data      = b_vlsm_llctrl.s_pl_crc_data      ;
assign b_rplh_spif.s_pl_rx_flush      = b_vlsm_llctrl.s_pl_rx_flush      ;
assign b_rplh_spif.s_pl_rx_nak        = b_vlsm_llctrl.s_pl_rx_nak        ;
assign b_rplh_spif.s_pl_dlp_start     = b_vlsm_llctrl.s_pl_dlp_start     ;
assign b_rplh_spif.s_pl_dlp_end       = b_vlsm_llctrl.s_pl_dlp_end       ;
assign b_rplh_spif.s_pl_tlp_start     = b_vlsm_llctrl.s_pl_tlp_start     ;
assign b_rplh_spif.s_pl_tlp_end       = b_vlsm_llctrl.s_pl_tlp_end       ;
assign b_rplh_spif.s_pl_tlp_edb       = b_vlsm_llctrl.s_pl_tlp_edb       ;
assign b_rplh_spif.s_pl_error         = b_vlsm_llctrl.s_pl_error         ;
assign b_rplh_spif.s_pl_nullified     = b_vlsm_llctrl.s_pl_nullified     ;
assign b_rplh_spif.s_pl_poisoned      = b_vlsm_llctrl.s_pl_poisoned      ;
assign b_rplh_spif.s_pl_dllp_valid    = b_vlsm_llctrl.s_pl_dllp_valid    ;
assign b_rplh_spif.s_pl_dllp_ofc      = b_vlsm_llctrl.s_pl_dllp_ofc      ;
assign b_rplh_spif.s_pl_dllp_data     = b_vlsm_llctrl.s_pl_dllp_data     ;

DWC_cxl_mem_cache_flit_buff
 u_cxl_flit_buff (                                               
    // Interfaces                                             
    .b_rplh_spif        ( b_rplh_spif.rplh_slave_mp           ),
    .b_rx_arb_llctrl    ( b_rx_arb_llctrl.master_rx_mp        ),
    // Inputs                                                 
    .core_clk           ( b_clk.s_core_clk                    ),
    .core_rst_n         ( b_clk.s_core_rst_n                  ),
    .cxl_protocol_cfg   ( cxl_protocol_cfg                    )
);

// -------------------------------------------------------------------------------------
// CXL Receiver Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rx
 U_DWC_cxl_mem_cache_rx (
    .b_clk                                 ( b_clk                                       ),
    .b_cdm                                 ( b_rx_cdm.master_rx_mp                       ),
    .cxl_protocol_cfg                      ( cxl_protocol_cfg                            ),
    .b_arb_llctrl                          ( b_rx_arb_llctrl.slave_rx_mp                 ),
    .b_rxdl_llctrl                         ( b_rxdl_llctrl.master_mp                     ),
    .cxl_pl_block_dl_init                  ( b_vlsm_llctrl.s_pl_block_dl_init            ),
    .ras_dp_err_inj                        ( ras_dp_err_inj_s                            ),
    .ras_dp_err_log                        ( ras_dp_err_log_rx                           ),
    .ras_dp_uncorr_err                     ( ras_dp_uncorr_err_rx_core                   ),
    .cxl_rx_link_disable                   ( cxl_link_disable                            ),
    .cxl_rx_active_req                     ( b_vlsm_llctrl.s_pl_rx_active_req            ),
    .cxl_rx_active_sts                     ( cxl_rx_active_sts                           ),
    .b_app_cache_init                      ( b_app_cache_rx_init                         ),
    .b_app_mem_init                        ( b_app_mem_rx_init                           ),
    .b_app_host_chi                        ( b_app_host_rx_chi                           ),
    .b_app_dev_chi                         ( b_app_dev_rx_chi                            ),
    .cxl_rx_dltl_ras_valid_err             ( s_ras_stat_cxl_vld_err                      ),
    .b_cxl_mst_hreq_drsp_ram               ( b_cxl_mst_hreq_drsp_ram                     ),
    .b_cxl_mst_hrsp_dreq_ram               ( b_cxl_mst_hrsp_dreq_ram                     ),
    .b_cxl_mst_hd_data_ram                 ( b_cxl_mst_hd_data_ram                       ),
    .b_cxl_mst_ms_ndr_ram                  ( b_cxl_mst_ms_ndr_ram                        ),
    .b_cxl_mst_ms_data_ram                 ( b_cxl_mst_ms_data_ram                       ),
    .b_cxl_mst_mrsp_ssnp_bi_ram            ( b_cxl_mst_mrsp_ssnp_bi_ram                  ),
    .cxl_ras_cache_poison                  ( cxl_rx_cache_poison_s                       ),
    .cxl_ras_mem_poison                    ( cxl_rx_mem_poison_s                         ),
    .cxl_rx_crc_error_hit                  ( cxl_rx_crc_error_hit_s                      ),
    .cxl_rx_rsvd_enc_error                 ( cxl_rx_rsvd_enc_error_s                     ),
    .cxl_rx_tl_fifo_data_out_ptr_err       ( cxl_rx_fifo_ptr_err_s                       ),
    .cxl_rx_fifo_ovflw                     ( cxl_rx_fifo_ovflw_s                         ),
    .cxl_rx_mdh_error                      ( cxl_rx_mdh_error_s                          ),
    .cxl_rx_tl_pending                     ( cxl_rx_tl_pending                           ),
    .cxl_rx_flit_data_chk                  ( cxl_rx_flit_data_chk_s                      ),
    .cxl_rx_flit_data                      ( cxl_rx_flit_data_s                          )
); // U_DWC_cxl_mem_cache_rx


// -------------------------------------------------------------------------------------
// CXL RAS Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_ras
 u_DWC_cxl_mem_cache_ras (
    .b_clk                                 ( b_clk                                       ),
    .cfg_dev_mode                          ( b_vlsm_llctrl.s_pl_device_port              ),
    .cfg_viral_enable                      ( b_cxl_cdm.s_cfg_cxl_viral_enable            ),
    .cfg_viral_status                      ( b_cxl_cdm.s_cfg_cxl_viral_status            ),
    .cfg_pl_reg_viral_status               ( b_cxl_cdm.s_cfg_cxl_pl_reg_viral_status     ), 
    .cfg_uncorr_error_mask                 ( b_cxl_cdm.s_mbar0_ras_uncorr_error_mask     ),
    .cfg_uncorr_error_severity             ( b_cxl_cdm.s_mbar0_ras_uncorr_error_severity ),
    .cfg_corr_error_mask                   ( b_cxl_cdm.s_mbar0_ras_corr_error_mask       ),
    .cfg_poison_enable                     ( b_cxl_cdm.s_mbar0_ras_poison_enabled        ),
    .cxl_lrsm_retry_hit                    ( b_tx_cdm.s_cxl_lrsm_retry_hit               ),
    .cxl_lrsm_reinit_hit                   ( b_tx_cdm.s_cxl_lrsm_reinit_hit              ),
    .cxl_lrsm_uc_err                       ( b_tx_cdm.s_lrsm_uc_err                      ),
    .cxl_lrsm_abort_state                  ( b_tx_cdm.s_lrsm_state[LRSM_STATE_WD-1]      ),
    .cxl_ack_cnt_ovflw                     ( b_tx_cdm.s_cxl_ack_cnt_ovflw                ),
    .cxl_rbuf_eseq_ovflw                   ( b_tx_cdm.s_cxl_rbuf_eseq_ovflw              ),
    .cxl_init_retry_error                  ( b_tx_cdm.s_cxl_init_retry_error             ),
    .cxl_init_multi_error                  ( b_tx_cdm.s_cxl_init_multi_error             ),
    .cxl_rx_ll_flit_error                  ( b_rx_cdm.s_cxl_rx_control_flit_error        ),
    .cxl_rsvd_crd_enc_error                ( b_tx_cdm.s_cxl_rsvd_crd_enc_error           ),
    .cxl_rx_ll_crdret_error                ( b_tx_cdm.s_cxl_ll_crdret_error              ),
    .cxl_rx_retry_ack_viral                ( b_rx_cdm.s_cxl_rx_rcvd_retry_ack_viral      ),
    .cxl_tx_fifo_ovflw_i                   ( cxl_tx_fifo_ovflw_s                         ),
    .cxl_rx_fifo_ovflw_i                   ( cxl_rx_fifo_ovflw_s                         ),
    .cxl_rx_fifo_ptr_err_i                 ( cxl_rx_fifo_ptr_err_s                       ),
    .cxl_rx_mdh_error_i                    ( cxl_rx_mdh_error_s                          ),
    .cxl_rx_crc_error_hit_i                ( cxl_rx_crc_error_hit_s                      ),
    .cxl_rx_rsvd_enc_error_i               ( cxl_rx_rsvd_enc_error_s                     ),
    .cxl_rx_flit_data_i                    ( cxl_rx_flit_data_s[511:0]                   ),
    .cxl_rx_cache_poison_i                 ( cxl_rx_cache_poison_s                       ),
    .cxl_rx_mem_poison_i                   ( cxl_rx_mem_poison_s                         ),
    .ras_stat_cxl_vld_err                  ( s_ras_stat_cxl_vld_err                      ),
    .cxl_ras_stat_rx_corr                  ( cxl_ras_stat_rx_corr                        ),
    .cxl_ras_stat_rx_uncorr                ( cxl_ras_stat_rx_uncorr                      ),
    .cxl_ras_stat_rx_hdr_log               ( cxl_ras_stat_rx_hdr_log                     ),
    .ras_stat_cxl_tx_uncorr                ( ras_dp_uncorr_err_tx                        ),
    .ras_stat_cxl_rx_uncorr                ( ras_dp_uncorr_err_rx                        ),
    .cxl_viral_request                     ( cxl_viral_request                           ),
    .cfg_cxl_fatal_error_o                 ( cxl_fatal_error_s                           ),
    .cfg_viral_status_set_o                ( b_cxl_cdm.s_cfg_cxl_dev_viral_status_set    ),
    .cxl_viral_status_set_o                ( b_tx_cdm.s_cfg_viral_status_set             ),
    .cfg_pl_reg_viral_status_set_o         ( b_cxl_cdm.s_cfg_cxl_pl_reg_viral_status_set ),
    .ras_corr_sts_o                        ( ras_corr_sts_s                              ),
    .ras_uncorr_sts_o                      ( ras_uncorr_sts_s                            ),
    .ras_header_log_o                      ( ras_header_log_s                            )
); // u_DWC_cxl_mem_cache_ras

endmodule
