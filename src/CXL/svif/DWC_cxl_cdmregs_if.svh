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
// ---   $DateTime: 2024/01/10 14:23:51 $
// ---   $Revision: #17 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/svif/DWC_cxl_cdmregs_if.svh#17 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_CXL_CDMREGS_IF__SVH__
`define __GUARD__DWC_CXL_CDMREGS_IF__SVH__
`include "DWC_pcie_ctl_pkg.svh"

interface DWC_cxl_cdmregs_if
  import DWC_cxl_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  #();


  // CDM Register Inputs
  logic                s_mbar0_ras_unc_cache_data_parity;
  logic                s_mbar0_ras_unc_cache_addr_parity;
  logic                s_mbar0_ras_unc_cache_be_parity;
  logic                s_mbar0_ras_unc_cache_data_ecc;
  logic                s_mbar0_ras_unc_mem_data_parity;
  logic                s_mbar0_ras_unc_mem_addr_parity;
  logic                s_mbar0_ras_unc_mem_be_parity;
  logic                s_mbar0_ras_unc_mem_data_ecc;
  logic                s_mbar0_ras_unc_reinit_threshold;
  logic                s_mbar0_ras_unc_rsvd_encoding_violation;
  logic                s_mbar0_ras_unc_poison_received;
  logic                s_mbar0_ras_unc_receiver_overflow;
  logic                s_mbar0_ras_unc_internal_error;
  logic                s_mbar0_ras_unc_cxl_ide_tx_error;
  logic                s_mbar0_ras_unc_cxl_ide_rx_error;
  logic                s_mbar0_ras_corr_cache_data_ecc;
  logic                s_mbar0_ras_corr_mem_data_ecc;
  logic                s_mbar0_ras_corr_crc_threshold;
  logic                s_mbar0_ras_corr_retry_threshold;
  logic                s_mbar0_ras_corr_cache_poison_received;
  logic                s_mbar0_ras_corr_mem_poison_received;
  logic                s_mbar0_ras_corr_physical_layer_error;
  logic  [31:0]        s_mbar0_ras_header_log_reg0;
  logic  [31:0]        s_mbar0_ras_header_log_reg1;
  logic  [31:0]        s_mbar0_ras_header_log_reg2;
  logic  [31:0]        s_mbar0_ras_header_log_reg3;
  logic  [31:0]        s_mbar0_ras_header_log_reg4;
  logic  [31:0]        s_mbar0_ras_header_log_reg5;
  logic  [31:0]        s_mbar0_ras_header_log_reg6;
  logic  [31:0]        s_mbar0_ras_header_log_reg7;
  logic  [31:0]        s_mbar0_ras_header_log_reg8;
  logic  [31:0]        s_mbar0_ras_header_log_reg9;
  logic  [31:0]        s_mbar0_ras_header_log_reg10;
  logic  [31:0]        s_mbar0_ras_header_log_reg11;
  logic  [31:0]        s_mbar0_ras_header_log_reg12;
  logic  [31:0]        s_mbar0_ras_header_log_reg13;
  logic  [31:0]        s_mbar0_ras_header_log_reg14;
  logic  [31:0]        s_mbar0_ras_header_log_reg15;
  logic  [3:0]         s_mbar0_link_ver_received;
  logic  [7:0]         s_mbar0_link_llr_wrap_val_received;
  logic  [4:0]         s_mbar0_link_num_retry_received;
  logic  [4:0]         s_mbar0_link_num_phy_reinit_received;
  logic  [7:0]         s_mbar0_link_wr_ptr_received;
  logic  [7:0]         s_mbar0_link_echo_eseq_received;
  logic  [7:0]         s_mbar0_link_num_free_buf_received;
  logic                s_mbar0_link_ll_reset_clr;
  logic  [1:0]         s_mbar0_link_init_state;
  logic  [7:0]         s_mbar0_link_ll_retry_buffer_consumed;
  logic  [9:0]         s_mbar0_link_rx_cache_req_credits_stat;
  logic  [9:0]         s_mbar0_link_rx_cache_rsp_credits_stat;
  logic  [9:0]         s_mbar0_link_rx_cache_data_credits_stat;
  logic  [9:0]         s_mbar0_link_rx_mem_req_rsp_credits_stat;
  logic  [9:0]         s_mbar0_link_rx_mem_data_credits_stat;
  logic  [9:0]         s_mbar0_link_tx_cache_req_credits_stat;
  logic  [9:0]         s_mbar0_link_tx_cache_rsp_credits_stat;
  logic  [9:0]         s_mbar0_link_tx_cache_data_credits_stat;
  logic  [9:0]         s_mbar0_link_tx_mem_req_rsp_credits_stat;
  logic  [9:0]         s_mbar0_link_tx_mem_data_credits_stat;
  logic  [9:0]         s_mbar0_link_rx_mem_bi_credits_stat;
  logic  [9:0]         s_mbar0_link_tx_mem_bi_credits_stat;

  // CDM Register Outputs
  // DVSEC Flex Bus Port Capability Offset (0Ah)
  logic                s_cfg_cxl_port_cache_capable;
  logic                s_cfg_cxl_port_mem_capable;
  logic  [15:0]        s_cfg_cxl_port_vid;
  logic                s_cfg_cxl_port_68B_flit_vh_capable;      
  logic                s_cfg_cxl_port_mld_capable;         
  logic                s_cfg_cxl_port_lopt_flit_capable;
  logic                s_cfg_cxl_port_pbr_flit_capable;
  // DVSEC Flex Bus Port Control (Offset 0Ch)
  logic                s_cfg_cxl_port_io_enable;
  logic                s_cfg_cxl_port_cache_enable;
  logic                s_cfg_cxl_port_mem_enable;
  logic                s_cfg_cxl_port_sync_hdr_bypass_enable;
  logic                s_cfg_cxl_port_drift_buffer_enable;
  logic                s_cfg_cxl_port_68B_flit_vh_enable;       
  logic                s_cfg_cxl_port_mld_enable;          
  logic                s_cfg_cxl_port_lopt_flit_enable;
  logic                s_cfg_cxl_port_pbr_flit_enable;
  logic                s_cfg_cxl_port_disable_cxl1p1_training; 
  logic                s_cfg_cxl_port_retimer1_present;
  logic                s_cfg_cxl_port_retimer2_present;
  logic                s_cfg_cxl_port_retimers_pre_mismatched;
  logic                s_cfg_cxl_viral_enable;
  logic                s_cfg_cxl_viral_status;
  logic                s_cfg_cxl_pl_reg_viral_status;
  logic                s_cfg_cxl_pl_reg_viral_status_set;
  // DVSEC Flex Bus Port Capability2 Offset (14h)
  logic                s_cfg_cxl_port_nop_hint_capable;
  // DVSEC Flex Bus Port Control2 (Offset 18h)
  logic                s_cfg_cxl_port_nop_hint_enable;
  // DVSEC Flex Bus Control (Offset 0Ch)
  logic  [`CX_CXL_NLD_PLUS_1-1:0]     s_cfg_cxl_dev_io_enable;
  logic                               s_cfg_cxl_dev_cache_enable;
  logic  [`CX_CXL_NLD_PLUS_1-1:0]     s_cfg_cxl_dev_mem_enable;
  logic  [4:0]                        s_cfg_cxl_dev_cache_sf_coverage;
  logic  [2:0]                        s_cfg_cxl_dev_cache_sf_granularity;
  logic                               s_cfg_cxl_dev_cache_clean_eviction;
  logic  [`CX_CXL_NLD_PLUS_1-1:0]     s_cfg_cxl_dev_viral_enable;
  logic  [`CX_CXL_NLD_PLUS_1-1:0]     s_cfg_cxl_dev_cxl_rst_mem_clr_enable;
  logic  [`CX_CXL_NLD_PLUS_1-1:0]     s_cfg_cxl_dev_post_cold_rst_volatile_hdm_default;
  logic  [`CX_CXL_NLD_PLUS_1-1:0]     s_cfg_cxl_dev_post_warm_rst_volatile_hdm_default;
  logic  [`CX_CXL_NLD_PLUS_1-1:0]     s_cfg_cxl_dev_post_hot_rst_volatile_hdm_default;
  logic  [`CX_CXL_NLD_PLUS_1-1:0]     s_cfg_cxl_dev_post_hot_rst_volatile_hdm_desired;
  logic  [`CX_CXL_NLD_PLUS_1-1:0]     s_cfg_cxl_dev_viral_status;
  logic                               s_cfg_cxl_dev_viral_status_set;
  logic                               s_cfg_cxl_dev_disable_caching; 
  logic                               s_cfg_cxl_dev_initiate_cache_wr_invld; 
  logic  [`CX_CXL_NLD_PLUS_1-1:0]     s_cfg_cxl_dev_initiate_cxl_rst; 

  logic  [`CX_CXL_NLD_PLUS_1-1:0][31:0]        s_cfg_cxl_dev_range1_mem_size_high;      
  logic  [`CX_CXL_NLD_PLUS_1-1:0]              s_cfg_cxl_dev_range1_mem_info_valid;     
  logic  [`CX_CXL_NLD_PLUS_1-1:0]              s_cfg_cxl_dev_range1_mem_active;         
  logic  [`CX_CXL_NLD_PLUS_1-1:0][4:0]         s_cfg_cxl_dev_range1_desired_interleave;
  logic  [`CX_CXL_NLD_PLUS_1-1:0][2:0]         s_cfg_cxl_dev_range1_mem_active_timeout;
  logic  [`CX_CXL_NLD_PLUS_1-1:0][3:0]         s_cfg_cxl_dev_range1_mem_size_low;
  logic  [`CX_CXL_NLD_PLUS_1-1:0][31:0]        s_cfg_cxl_dev_range1_mem_base_high;
  logic  [`CX_CXL_NLD_PLUS_1-1:0][3:0]         s_cfg_cxl_dev_range1_mem_base_low;
  logic  [`CX_CXL_NLD_PLUS_1-1:0][31:0]        s_cfg_cxl_dev_range2_mem_size_high;      
  logic  [`CX_CXL_NLD_PLUS_1-1:0]              s_cfg_cxl_dev_range2_mem_info_valid;     
  logic  [`CX_CXL_NLD_PLUS_1-1:0]              s_cfg_cxl_dev_range2_mem_active;         
  logic  [`CX_CXL_NLD_PLUS_1-1:0][4:0]         s_cfg_cxl_dev_range2_desired_interleave;
  logic  [`CX_CXL_NLD_PLUS_1-1:0][2:0]         s_cfg_cxl_dev_range2_mem_active_timeout;
  logic  [`CX_CXL_NLD_PLUS_1-1:0][3:0]         s_cfg_cxl_dev_range2_mem_size_low;
  logic  [`CX_CXL_NLD_PLUS_1-1:0][31:0]        s_cfg_cxl_dev_range2_mem_base_high;
  logic  [`CX_CXL_NLD_PLUS_1-1:0][3:0]         s_cfg_cxl_dev_range2_mem_base_low;
  logic  [16:0]        s_mbar0_ras_uncorr_error_mask;
  logic  [16:0]        s_mbar0_ras_uncorr_error_severity;
  logic  [6:0]         s_mbar0_ras_corr_error_mask; 
  logic                s_mbar0_ras_poison_enabled;
  logic  [1:0]         s_mbar0_security_device_trust_level;
  logic  [3:0]         s_mbar0_link_ver_supported;
  logic  [7:0]         s_mbar0_link_llr_wrap_val_supported;
  logic                s_mbar0_link_ll_reset;
  logic                s_mbar0_link_ll_init_stall;
  logic                s_mbar0_link_ll_crd_stall;
  logic  [9:0]         s_mbar0_link_rx_cache_req_credits;
  logic  [9:0]         s_mbar0_link_rx_cache_rsp_credits;
  logic  [9:0]         s_mbar0_link_rx_cache_data_credits;
  logic  [9:0]         s_mbar0_link_rx_mem_req_rsp_credits;
  logic  [9:0]         s_mbar0_link_rx_mem_data_credits;
  logic  [9:0]         s_mbar0_link_rx_mem_bi_credits;
  logic  [7:0]         s_mbar0_link_ack_force_threshold;
  logic  [9:0]         s_mbar0_link_ack_flush_retimer;
  logic                s_mbar0_link_mdh_disable;
  logic  [3:0]         s_mbar0_arb_mux_cxl_io;
  logic  [3:0]         s_mbar0_arb_mux_cxl_cache_mem;
  logic  [31:0]        s_mbar0_cap_header_reg;
  logic  [31:0]        s_mbar0_ras_cap_header_reg;
  logic  [31:0]        s_mbar0_security_cap_header_reg;
  logic  [31:0]        s_mbar0_link_cap_header_reg;
  logic  [6:0]         s_mbar0_ras_corr_reg;
  logic  [16:0]        s_mbar0_ras_uncorr_reg;
  logic  [31:0]        s_cxl_fatal_error_reg;
  logic  [31:0]        s_pl_reg_fatal_error;   // CXL Fatal Error Bus
  logic  [5:0]         s_pl_reg_lrsm_state;               //Reflects the current state of the LRSM
  logic                s_pl_reg_lrsm_fatal_error;         //Asserted when unexpected Retry.Ack is received or LRSM reaches Abort state.  
  logic                s_pl_reg_vlsm_pm_enable;           //Enables Low Power mode entry.
  logic                s_pl_reg_apn_bypass_enable;        //Enable to bypass Alternate Protocol Negotiation (APN)
  logic                s_pl_reg_apn_sw_mode;              //Alternate Protocol Negotiation mode for SW device
  logic                s_pl_reg_vlsm_to_active;           //Force VLSM to Active State.
  logic  [4:0]         s_pl_reg_max_num_retry;            //Maximum number of retry attempts before transitioning to Recovery.
  logic  [4:0]         s_pl_reg_max_num_reinit;           //Maximum number of transitions to recovery before aborting the retry sequence.
  logic  [15:0]        s_pl_reg_lrsm_timeout_threshold;   //Sets the threshold for the retry timeout. This indicates the number of flits which can be transmitted while waiting for a Retry.Ack before a retry timeout occurs.
  logic  [9:0]         s_pl_reg_crc_threshold;            //
  logic                s_pl_reg_cm_ll_cache_poison_injection_start;   // CXL.cache/CXL.mem LinkLayerErrorInjection - Cache Poison Injection Start
  logic                s_pl_reg_cm_ll_cache_poison_injection_busy;    // CXL.cache/CXL.mem LinkLayerErrorInjection - Cache Poison Injection Busy
  logic                s_pl_reg_cm_ll_mem_poison_injection_start;     // CXL.cache/CXL.mem LinkLayerErrorInjection - Mem Poison Injection Start
  logic                s_pl_reg_cm_ll_mem_poison_injection_busy;      // CXL.cache/CXL.mem LinkLayerErrorInjection - Mem Poison Injection Busy
  logic  [1:0]         s_pl_reg_cm_ll_cache_mem_crc_injection;        // CXL.cache/CXL.mem LinkLayerErrorInjection - CRC Error Injection Start
  logic  [1:0]         s_pl_reg_cm_ll_cache_mem_crc_injection_count;  // CXL.cache/CXL.mem LinkLayerErrorInjection - CRC Error Injection Count
  logic                s_pl_reg_cm_ll_cache_mem_crc_injection_busy;   // CXL.cache/CXL.mem LinkLayerErrorInjection - CRC Error Injection Busy
// Outputs from CXL 2.0 Extension DVSEC
  logic                s_cfg_cxl_2_0_ext_viral_status;              // Switch Port has entered Viral
  logic                s_cfg_cxl_2_0_ext_unmask_sbr;                // Unmask SBR
  logic                s_cfg_cxl_2_0_ext_unmask_ld;                 // Unmask Link Disable
  logic                s_cfg_cxl_2_0_ext_alt_mse;                   // Alternate Memory Space Enable 
  logic                s_cfg_cxl_2_0_ext_alt_bme;                   // Alternate Bus Master Enable
  logic                s_cfg_cxl_2_0_ext_viral_en;                  // Viral Enable for Switch
  logic  [7:0]         s_cfg_cxl_2_0_ext_alt_bus_base;              // Alternate Bus Base
  logic  [7:0]         s_cfg_cxl_2_0_ext_alt_bus_limit;             // Alternate Bus Limit
  logic  [11:0]        s_cfg_cxl_2_0_ext_alt_mem_base;              // Alternate Memory Base
  logic  [11:0]        s_cfg_cxl_2_0_ext_alt_mem_limit;             // Alternate Memory Limit
  logic  [11:0]        s_cfg_cxl_2_0_ext_alt_pref_mem_base;         // Alternate Prefetchable Memory Base
  logic  [11:0]        s_cfg_cxl_2_0_ext_alt_pref_mem_limit;        // Alternate Memory Limit
  logic  [31:0]        s_cfg_cxl_2_0_ext_alt_pref_mem_base_high;    // Alternate Prefetchable Memory Base High
  logic  [31:0]        s_cfg_cxl_2_0_ext_alt_pref_mem_limit_high;   // Alternate Prefetchable Memory Base High
  logic                s_cfg_cxl_2_0_ext_rcrb_en;                   // CXL RCRB Enable                           
  logic  [18:0]        s_cfg_cxl_2_0_ext_rcrb_base_addr_low;        // CXL RCRB Base Address Low
  logic  [31:0]        s_cfg_cxl_2_0_ext_rcrb_base_addr_high;       // RCRB Base Address High

  // MEM CACHE Link Layer Control and Status Register Fields
  // Inputs from configuration space
  logic                                 s_cfg_ll_reset;               // Link Layer Reset
  logic                                 s_cfg_ll_init_stall;          // Stall Init.Param transmission
  logic                                 s_cfg_ll_crd_stall;           // Stall Credit Initialization
  logic                                 s_cfg_viral_status;           // Viral Indication
  logic                                 s_cfg_viral_status_set;       // Viral Mode Detected
  logic [(ACK_CNT_WD - 1) : 0]          s_cfg_ack_force_threshold;    // Ack timer threshold
  logic [(ACK_FLUSH_TIMER_WD - 1) : 0]  s_cfg_ack_flush_timer;        // Flush timer threshold
  logic                                 s_cfg_cxl_mdh_disable;        // Disable Multi-Data Header flits
  logic                                 s_cfg_dev_mode;               // Indicates whether CXL Controller operates in Device(0) or Host(1) mode
  logic [(MAX_RETRY_WD - 1) : 0]        s_cfg_max_retry;              // Maximum allowed number of retries
  logic [(MAX_REINIT_WD - 1) : 0]       s_cfg_max_reinit;             // Maximum allowed number of retrains
  logic [(RETRY_TIMER_WD - 1) : 0]      s_cfg_retry_timer;            // Retry timer target value
  logic [(RBUF_ADD_WD - 1) : 0]         s_cfg_llr_wrap_value;         // Retry buffer wrap value
  logic [(RBUF_ADD_WD - 1) : 0]         s_cfg_rx_rcvd_llr_wrap;       // Received Retry Buffer Wrap Value
  logic [(CXL_VERSION_WD - 1) : 0]      s_cfg_cxl_version;            // CXL Version
  // Outputs to configuration space
  logic                                 s_cxl_lrsm_retry_hit;         // LRSM Retry Threshold Hit
  logic                                 s_cxl_lrsm_reinit_hit;        // LRSM Reinit Threshold Hit
  logic                                 s_lrsm_uc_err;                // Uncorrectable error detected in the LRSM
  logic [(LRSM_STATE_WD - 1) : 0]       s_lrsm_state;                 // LRSM FSM State
  logic [(LL_CSR_STATE_WD - 1) : 0]     s_cfg_ll_init_state;          // Init FSM state
  logic [(RBUF_ADD_WD - 1) : 0]         s_cfg_ll_rbuf_consumed;       // Retry Buffer Spaces Consumed
  logic                                 s_cxl_ack_cnt_ovflw;          // Ack Counter Overflow
  logic                                 s_cxl_rsvd_crd_enc_error;     // CXL Reserved Credit Encoding Error
  logic [5:0]                           s_cxl_ll_crdret_error;        // CXL Credit Return Overflow
  logic                                 s_cxl_init_retry_error;       // RAS - Link Init Retryable Flit Error
  logic                                 s_cxl_init_multi_error;       // RAS - Link Init Multiple Init.Param Error
  logic                                 s_cxl_rbuf_eseq_ovflw;        // RAS - Retry buffer ESEQ Overflow
  logic [(TX_CREDIT_WD - 1) : 0]        s_cfg_tx_cache_req_credits;   // Credit Stat - TX Cache Request Credits
  logic [(TX_CREDIT_WD - 1) : 0]        s_cfg_tx_cache_rsp_credits;   // Credit Stat - TX Cache Response Credits
  logic [(TX_CREDIT_WD - 1) : 0]        s_cfg_tx_cache_data_credits;  // Credit Stat - TX Cache Data Credits
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_cache_req_crdrets;   // Credit Stat - RX Cache Request Accumulated Credit Returns
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_cache_rsp_crdrets;   // Credit Stat - RX Cache Response Accumulated Credit Returns
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_cache_data_crdrets;  // Credit Stat - RX Cache Data Accumulated Credit Returns
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_cache_req_credits;   // Credit Config - RX Cache Request Credits
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_cache_rsp_credits;   // Credit Config - RX Cache Response Credits
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_cache_data_credits;  // Credit Config - RX Cache Data Credits
  logic [(TX_CREDIT_WD - 1) : 0]        s_cfg_tx_mem_data_credits;    // Credit Stat - TX Mem Data Credits
  logic [(TX_CREDIT_WD - 1) : 0]        s_cfg_tx_mem_req_rsp_credits; // Credit Stat - TX Mem Request Response Credits
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_mem_data_crdrets;    // Credit Stat - RX Mem Data Accumulated Credit Returns
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_mem_req_rsp_crdrets; // Credit Stat - RX Mem Request Accumulated Credit Returns
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_mem_data_credits;    // Credit Config - RX Mem Data Credits
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_mem_ndr_credits;     // Credit Config - RX Mem Request Response Credits
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_mem_bi_credits;      //Credit Stat - Rx BI credits
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_tx_mem_bi_credits;       //Credit Stat - Tx BI Configured credits
  logic [(RX_CREDIT_WD - 1) : 0]        s_cfg_rx_mem_bi_crdrets;      //Credit Stat - Rx BI Accumulated credit Returns
  logic [1:0]                           s_cfg_mc_crc_err_inj;         // CacheMemCRCInjection
  logic [1:0]                           s_cfg_mc_crc_err_inj_cnt;     // CacheMemCRCInjection Count
  logic                                 s_cfg_mc_crc_err_inj_busy;    // CacheMemCRCInjection Busy
  logic                                 s_cfg_cache_poison_start;     // CachePoisonInjectionStart
  logic                                 s_cfg_cache_poison_busy;      // CachePoisonInjectionBusy
  logic                                 s_cfg_mem_poison_start;       // MemPoisonInjectionStart
  logic                                 s_cfg_mem_poison_busy;        // MemPoisonInjectionBusy

  //--------------------------------------------------------------------------
  // CMDREG signals from RX layer
  //
  //--------------------------------------------------------------------------
  logic  [CXL_VERSION_WD-1:0]     s_cxl_rx_rcvd_init_cxl_version;          // The remote CXL version
  logic  [MAX_RX_CRC_ERROR_WD-1:0] s_cxl_rx_max_crc_error;                 // RX CRC error thresold value
  logic  [ESEQ_WD-1:0]            s_cxl_rx_rcvd_init_llr_wrap_value;       // Indicates the value after which LLR sequence counter should wrap to zero
  logic                           s_cxl_rx_control_flit_error;             // Indicates that control flit received with error
  logic  [MAX_REINIT_WD-1:0]      s_cxl_rx_rcvd_retry_req_num_phy_reinit;  // Corresponds to NUM_PHY_REINIT field in Retry Request
  logic  [MAX_REINIT_WD-1:0]      s_cxl_rx_rcvd_retry_req_num_retry;       // Corresponds to NUM_RETRY field in Retry Request
  //logic                           s_cxl_rx_rcvd_retry_ack_empty;           // Empty bit indicates that the LLR contains no valid data and therefore the NUM_RETRY value should be reset
  logic                           s_cxl_rx_rcvd_retry_ack_viral;           // Viral bit indicates that the transmitting agent is in viral state
  logic  [7:0]                    s_cxl_rx_retry_ack_wrptr;                // Contains the WrPtr value of the retry queue for debug purposes
  logic  [ESEQ_WD-1:0]            s_cxl_rx_retry_ack_eseq;                 // Contains the echo of the Eseq from the LLR.Req
  logic  [RBUF_ADD_WD-1:0]        s_cxl_rx_retry_ack_numfreebuf;           // Contains the NumFreeBuf value of the retry queue for debug purposes


  ras_dp_err_log_t                  s_ras_dp_err_log; // Error Log from CXL RASDP Manager
  ras_dp_err_inj_t                  s_ras_dp_err_inj; // Error Injection for RASDP Manager
  




  modport master_mp(
    output  s_cfg_ll_reset,
    output  s_cfg_ll_init_stall,
    output  s_cfg_ll_crd_stall,
    output  s_cfg_viral_status,
    output  s_cfg_viral_status_set,
    output  s_cfg_ack_force_threshold,
    output  s_cfg_ack_flush_timer,
    output  s_cfg_cxl_mdh_disable,
    output  s_cfg_dev_mode,
    output  s_cfg_max_retry,
    output  s_cfg_max_reinit,
    output  s_cfg_retry_timer,
    output  s_cfg_llr_wrap_value,
    output  s_cfg_cxl_version,
    output  s_cfg_rx_rcvd_llr_wrap,
    output  s_cfg_rx_cache_req_credits,
    output  s_cfg_rx_cache_rsp_credits,
    output  s_cfg_rx_cache_data_credits,
    output  s_cfg_rx_mem_data_credits,
    output  s_cfg_rx_mem_ndr_credits,
    output   s_cfg_rx_mem_bi_credits,
    output  s_cfg_mc_crc_err_inj,
    output  s_cfg_mc_crc_err_inj_cnt,
    output  s_cfg_cache_poison_start,
    output  s_cfg_mem_poison_start,
    input   s_cfg_mc_crc_err_inj_busy,
    input   s_cfg_cache_poison_busy,
    input   s_cfg_mem_poison_busy,
    input   s_cxl_init_retry_error,
    input   s_cxl_init_multi_error,
    input   s_cxl_rbuf_eseq_ovflw,
    input   s_cxl_lrsm_retry_hit,
    input   s_cxl_lrsm_reinit_hit,
    input   s_lrsm_uc_err,
    input   s_lrsm_state,
    input   s_cfg_ll_init_state,
    input   s_cfg_ll_rbuf_consumed,
    input   s_cxl_ack_cnt_ovflw,
    input   s_cxl_rsvd_crd_enc_error,
    input   s_cxl_ll_crdret_error
    ,
    input   s_cfg_tx_cache_req_credits,
    input   s_cfg_tx_cache_rsp_credits,
    input   s_cfg_tx_cache_data_credits
    ,
    input   s_cfg_rx_cache_req_crdrets,
    input   s_cfg_rx_cache_rsp_crdrets,
    input   s_cfg_rx_cache_data_crdrets
    ,
    input   s_cfg_tx_mem_data_credits,
    input   s_cfg_tx_mem_req_rsp_credits,
    input   s_cfg_tx_mem_bi_credits,
    input   s_cfg_rx_mem_bi_crdrets,
    input   s_cfg_rx_mem_data_crdrets,
    input   s_cfg_rx_mem_req_rsp_crdrets
  );

  modport slave_mp(
    input   s_cfg_ll_reset,
    input   s_cfg_ll_init_stall,
    input   s_cfg_ll_crd_stall,
    input   s_cfg_viral_status,
    input   s_cfg_viral_status_set,
    input   s_cfg_ack_force_threshold,
    input   s_cfg_ack_flush_timer,
    input   s_cfg_cxl_mdh_disable,
    input   s_cfg_dev_mode,
    input   s_cfg_max_retry,
    input   s_cfg_max_reinit,
    input   s_cfg_retry_timer,
    input   s_cfg_llr_wrap_value,
    input   s_cfg_cxl_version,
    input   s_cfg_rx_rcvd_llr_wrap,
    input   s_cfg_rx_cache_req_credits,
    input   s_cfg_rx_cache_rsp_credits,
    input   s_cfg_rx_cache_data_credits,
    input   s_cfg_rx_mem_data_credits,
    input   s_cfg_rx_mem_ndr_credits,
    input   s_cfg_rx_mem_bi_credits,
    input   s_cfg_mc_crc_err_inj,
    input   s_cfg_mc_crc_err_inj_cnt,
    input   s_cfg_cache_poison_start,
    input   s_cfg_mem_poison_start,
    output  s_cfg_mc_crc_err_inj_busy,
    output  s_cfg_cache_poison_busy,
    output  s_cfg_mem_poison_busy,
    output  s_cxl_init_retry_error,
    output  s_cxl_init_multi_error,
    output  s_cxl_rbuf_eseq_ovflw,
    output  s_cxl_lrsm_retry_hit,
    output  s_cxl_lrsm_reinit_hit,
    output  s_lrsm_uc_err,
    output  s_lrsm_state,
    output  s_cfg_ll_init_state,
    output  s_cfg_ll_rbuf_consumed,
    output  s_cxl_ack_cnt_ovflw,
    output  s_cxl_rsvd_crd_enc_error,
    output  s_cxl_ll_crdret_error
    ,
    output  s_cfg_tx_cache_req_credits,
    output  s_cfg_tx_cache_rsp_credits,
    output  s_cfg_tx_cache_data_credits
    ,
    output  s_cfg_rx_cache_req_crdrets,
    output  s_cfg_rx_cache_rsp_crdrets,
    output  s_cfg_rx_cache_data_crdrets
    ,
    output  s_cfg_tx_mem_data_credits,
    output  s_cfg_tx_mem_req_rsp_credits
    ,
    output   s_cfg_tx_mem_bi_credits,
    output   s_cfg_rx_mem_bi_crdrets,
    output  s_cfg_rx_mem_data_crdrets,
    output  s_cfg_rx_mem_req_rsp_crdrets
  );


modport  master_rx_mp(
    input    s_cfg_dev_mode,
    input    s_cxl_rx_max_crc_error,
    input    s_cfg_cxl_mdh_disable,
    output   s_cxl_rx_rcvd_init_cxl_version,
    output   s_cxl_rx_rcvd_init_llr_wrap_value,
    output   s_cxl_rx_control_flit_error,
    output   s_cxl_rx_rcvd_retry_req_num_phy_reinit,
    output   s_cxl_rx_rcvd_retry_req_num_retry,
    //output   s_cxl_rx_rcvd_retry_ack_empty,
    output   s_cxl_rx_rcvd_retry_ack_viral,
    output   s_cxl_rx_retry_ack_wrptr,
    output   s_cxl_rx_retry_ack_eseq,
    output   s_cxl_rx_retry_ack_numfreebuf
);

modport  slave_rx_mp(
    output  s_cfg_dev_mode,
    output  s_cxl_rx_max_crc_error,
    output  s_cfg_cxl_mdh_disable,
    input   s_cxl_rx_rcvd_init_cxl_version,
    input   s_cxl_rx_rcvd_init_llr_wrap_value,
    input   s_cxl_rx_control_flit_error,
    input   s_cxl_rx_rcvd_retry_req_num_phy_reinit,
    input   s_cxl_rx_rcvd_retry_req_num_retry,
    //input   s_cxl_rx_rcvd_retry_ack_empty,
    input   s_cxl_rx_rcvd_retry_ack_viral,
    input   s_cxl_rx_retry_ack_wrptr,
    input   s_cxl_rx_retry_ack_eseq,
    input   s_cxl_rx_retry_ack_numfreebuf
);





  modport master_cdm_mp (
    input   s_mbar0_ras_unc_cache_data_parity,
    input   s_mbar0_ras_unc_cache_addr_parity,
    input   s_mbar0_ras_unc_cache_be_parity,
    input   s_mbar0_ras_unc_cache_data_ecc,
    input   s_mbar0_ras_unc_mem_data_parity,
    input   s_mbar0_ras_unc_mem_addr_parity,
    input   s_mbar0_ras_unc_mem_be_parity,
    input   s_mbar0_ras_unc_mem_data_ecc,
    input   s_mbar0_ras_unc_reinit_threshold,
    input   s_mbar0_ras_unc_rsvd_encoding_violation,
    input   s_mbar0_ras_unc_poison_received,
    input   s_mbar0_ras_unc_receiver_overflow,
    input   s_mbar0_ras_unc_internal_error,
    input   s_mbar0_ras_unc_cxl_ide_tx_error,
    input   s_mbar0_ras_unc_cxl_ide_rx_error,
    input   s_mbar0_ras_corr_cache_data_ecc,
    input   s_mbar0_ras_corr_mem_data_ecc,
    input   s_mbar0_ras_corr_crc_threshold,
    input   s_mbar0_ras_corr_retry_threshold,
    input   s_mbar0_ras_corr_cache_poison_received,
    input   s_mbar0_ras_corr_mem_poison_received,
    input   s_mbar0_ras_corr_physical_layer_error,
    input   s_mbar0_ras_header_log_reg0,
    input   s_mbar0_ras_header_log_reg1,
    input   s_mbar0_ras_header_log_reg2,
    input   s_mbar0_ras_header_log_reg3,
    input   s_mbar0_ras_header_log_reg4,
    input   s_mbar0_ras_header_log_reg5,
    input   s_mbar0_ras_header_log_reg6,
    input   s_mbar0_ras_header_log_reg7,
    input   s_mbar0_ras_header_log_reg8,
    input   s_mbar0_ras_header_log_reg9,
    input   s_mbar0_ras_header_log_reg10,
    input   s_mbar0_ras_header_log_reg11,
    input   s_mbar0_ras_header_log_reg12,
    input   s_mbar0_ras_header_log_reg13,
    input   s_mbar0_ras_header_log_reg14,
    input   s_mbar0_ras_header_log_reg15,
    input   s_mbar0_link_ver_received,
    input   s_mbar0_link_llr_wrap_val_received,
    input   s_mbar0_link_num_retry_received,
    input   s_mbar0_link_num_phy_reinit_received,
    input   s_mbar0_link_wr_ptr_received,
    input   s_mbar0_link_echo_eseq_received,
    input   s_mbar0_link_num_free_buf_received,
    input   s_mbar0_link_ll_reset_clr,
    input   s_mbar0_link_init_state,
    input   s_mbar0_link_ll_retry_buffer_consumed,
    input   s_mbar0_link_rx_cache_req_credits_stat,
    input   s_mbar0_link_rx_cache_rsp_credits_stat,
    input   s_mbar0_link_rx_cache_data_credits_stat,
    input   s_mbar0_link_rx_mem_req_rsp_credits_stat,
    input   s_mbar0_link_rx_mem_data_credits_stat,
    input   s_mbar0_link_tx_cache_req_credits_stat,
    input   s_mbar0_link_tx_cache_rsp_credits_stat,
    input   s_mbar0_link_tx_cache_data_credits_stat,
    input   s_mbar0_link_tx_mem_req_rsp_credits_stat,
    input   s_mbar0_link_tx_mem_data_credits_stat,
    input   s_mbar0_link_rx_mem_bi_credits_stat,
    input   s_mbar0_link_tx_mem_bi_credits_stat,
    input   s_pl_reg_lrsm_state,
    input   s_pl_reg_lrsm_fatal_error,
    input   s_pl_reg_cm_ll_cache_poison_injection_busy,
    input   s_pl_reg_cm_ll_mem_poison_injection_busy,
    input   s_pl_reg_cm_ll_cache_mem_crc_injection_busy,
    input   s_pl_reg_fatal_error,
    input   s_cfg_cxl_pl_reg_viral_status_set,
    input   s_cfg_cxl_dev_viral_status_set,
    input   s_ras_dp_err_log,
    output  s_ras_dp_err_inj,
    output  s_cfg_cxl_port_cache_capable,
    output  s_cfg_cxl_port_mem_capable,
    output  s_cfg_cxl_port_vid,
    output  s_cfg_cxl_port_68B_flit_vh_capable,      
    output  s_cfg_cxl_port_mld_capable,         
    output  s_cfg_cxl_port_lopt_flit_capable,
    output  s_cfg_cxl_port_pbr_flit_capable,
    output  s_cfg_cxl_port_nop_hint_capable,
    output  s_cfg_cxl_port_68B_flit_vh_enable,       
    output  s_cfg_cxl_port_mld_enable,          
    output  s_cfg_cxl_port_lopt_flit_enable,
    output  s_cfg_cxl_port_pbr_flit_enable,
    output  s_cfg_cxl_port_nop_hint_enable,
    output  s_cfg_cxl_port_disable_cxl1p1_training, 
    output  s_cfg_cxl_port_io_enable,
    output  s_cfg_cxl_port_cache_enable,
    output  s_cfg_cxl_port_mem_enable,
    output  s_cfg_cxl_port_sync_hdr_bypass_enable,
    output  s_cfg_cxl_port_drift_buffer_enable,
    output  s_cfg_cxl_port_retimer1_present,
    output  s_cfg_cxl_port_retimer2_present,
    output  s_cfg_cxl_port_retimers_pre_mismatched,
    output  s_cfg_cxl_viral_enable,
    output  s_cfg_cxl_viral_status,
    output  s_cfg_cxl_pl_reg_viral_status,
    output  s_cfg_cxl_dev_io_enable,
    output  s_cfg_cxl_dev_cache_enable,
    output  s_cfg_cxl_dev_mem_enable,
    output  s_cfg_cxl_dev_cache_sf_coverage,
    output  s_cfg_cxl_dev_cache_sf_granularity,
    output  s_cfg_cxl_dev_cache_clean_eviction,
    output  s_cfg_cxl_dev_viral_enable,
    output  s_cfg_cxl_dev_cxl_rst_mem_clr_enable,
    output  s_cfg_cxl_dev_post_cold_rst_volatile_hdm_default,
    output  s_cfg_cxl_dev_post_warm_rst_volatile_hdm_default,
    output  s_cfg_cxl_dev_post_hot_rst_volatile_hdm_default,
    output  s_cfg_cxl_dev_post_hot_rst_volatile_hdm_desired,
    output  s_cfg_cxl_dev_viral_status,
    output  s_cfg_cxl_dev_disable_caching, 
    output  s_cfg_cxl_dev_initiate_cache_wr_invld, 
    output  s_cfg_cxl_dev_initiate_cxl_rst,
    output  s_cfg_cxl_dev_range1_mem_size_high,      
    output  s_cfg_cxl_dev_range1_mem_info_valid,     
    output  s_cfg_cxl_dev_range1_mem_active,         
    output  s_cfg_cxl_dev_range1_desired_interleave,
    output  s_cfg_cxl_dev_range1_mem_active_timeout,
    output  s_cfg_cxl_dev_range1_mem_size_low,    
    output  s_cfg_cxl_dev_range1_mem_base_high,
    output  s_cfg_cxl_dev_range1_mem_base_low,
    output  s_cfg_cxl_dev_range2_mem_size_high,      
    output  s_cfg_cxl_dev_range2_mem_info_valid,     
    output  s_cfg_cxl_dev_range2_mem_active,         
    output  s_cfg_cxl_dev_range2_desired_interleave,
    output  s_cfg_cxl_dev_range2_mem_active_timeout,
    output  s_cfg_cxl_dev_range2_mem_size_low,     
    output  s_cfg_cxl_dev_range2_mem_base_high,
    output  s_cfg_cxl_dev_range2_mem_base_low,
    output  s_mbar0_ras_uncorr_error_mask,
    output  s_mbar0_ras_uncorr_error_severity,
    output  s_mbar0_ras_corr_error_mask, 
    output  s_mbar0_ras_poison_enabled,
    output  s_mbar0_security_device_trust_level,
    output  s_mbar0_link_ver_supported,
    output  s_mbar0_link_llr_wrap_val_supported,
    output  s_mbar0_link_ll_reset,
    output  s_mbar0_link_ll_init_stall,
    output  s_mbar0_link_ll_crd_stall,
    output  s_mbar0_link_rx_cache_req_credits,
    output  s_mbar0_link_rx_cache_rsp_credits,
    output  s_mbar0_link_rx_cache_data_credits,
    output  s_mbar0_link_rx_mem_req_rsp_credits,
    output  s_mbar0_link_rx_mem_data_credits,
    output  s_mbar0_link_rx_mem_bi_credits,
    output  s_mbar0_link_ack_force_threshold,
    output  s_mbar0_link_ack_flush_retimer,
    output  s_mbar0_link_mdh_disable,
    output  s_mbar0_arb_mux_cxl_io,
    output  s_mbar0_arb_mux_cxl_cache_mem,
    output  s_mbar0_cap_header_reg,
    output  s_mbar0_ras_cap_header_reg,
    output  s_mbar0_security_cap_header_reg,
    output  s_mbar0_link_cap_header_reg,
    output  s_mbar0_ras_corr_reg,
    output  s_mbar0_ras_uncorr_reg,
    output  s_cxl_fatal_error_reg,
    
    output  s_pl_reg_vlsm_pm_enable,
    output  s_pl_reg_apn_bypass_enable,
    output  s_pl_reg_apn_sw_mode,
    output  s_pl_reg_vlsm_to_active,
    output  s_pl_reg_max_num_retry,
    output  s_pl_reg_max_num_reinit,
    output  s_pl_reg_lrsm_timeout_threshold,
    output  s_pl_reg_crc_threshold,
    output  s_pl_reg_cm_ll_cache_poison_injection_start,
    output  s_pl_reg_cm_ll_mem_poison_injection_start,
    output  s_pl_reg_cm_ll_cache_mem_crc_injection,
    output  s_pl_reg_cm_ll_cache_mem_crc_injection_count
   ,output  s_cfg_cxl_2_0_ext_unmask_sbr,                // Unmask SBR
    output  s_cfg_cxl_2_0_ext_viral_status,
    output  s_cfg_cxl_2_0_ext_unmask_ld,                 // Unmask Link Disable
    output  s_cfg_cxl_2_0_ext_alt_mse,                   // Alternate Memory Space Enable 
    output  s_cfg_cxl_2_0_ext_alt_bme,                   // Alternate Bus Master Enable
    output  s_cfg_cxl_2_0_ext_viral_en,                  // Viral Enable for Switch
    output  s_cfg_cxl_2_0_ext_alt_bus_base,              // Alternate Bus Base
    output  s_cfg_cxl_2_0_ext_alt_bus_limit,             // Alternate Bus Limit
    output  s_cfg_cxl_2_0_ext_alt_mem_base,              // Alternate Memory Base
    output  s_cfg_cxl_2_0_ext_alt_mem_limit,             // Alternate Memory Limit
    output  s_cfg_cxl_2_0_ext_alt_pref_mem_base,         // Alternate Prefetchable Memory Base
    output  s_cfg_cxl_2_0_ext_alt_pref_mem_limit,        // Alternate Memory Limit
    output  s_cfg_cxl_2_0_ext_alt_pref_mem_base_high,    // Alternate Prefetchable Memory Base High
    output  s_cfg_cxl_2_0_ext_alt_pref_mem_limit_high,   // Alternate Prefetchable Memory Base High
    output  s_cfg_cxl_2_0_ext_rcrb_en,                   // CXL RCRB Enable                           
    output  s_cfg_cxl_2_0_ext_rcrb_base_addr_low,        // CXL RCRB Base Address Low
    output  s_cfg_cxl_2_0_ext_rcrb_base_addr_high        // RCRB Base Address High
  );


  modport slave_cdm_mp (
    output  s_mbar0_ras_unc_cache_data_parity,
    output  s_mbar0_ras_unc_cache_addr_parity,
    output  s_mbar0_ras_unc_cache_be_parity,
    output  s_mbar0_ras_unc_cache_data_ecc,
    output  s_mbar0_ras_unc_mem_data_parity,
    output  s_mbar0_ras_unc_mem_addr_parity,
    output  s_mbar0_ras_unc_mem_be_parity,
    output  s_mbar0_ras_unc_mem_data_ecc,
    output  s_mbar0_ras_unc_reinit_threshold,
    output  s_mbar0_ras_unc_rsvd_encoding_violation,
    output  s_mbar0_ras_unc_poison_received,
    output  s_mbar0_ras_unc_receiver_overflow,
    output  s_mbar0_ras_unc_internal_error,
    output  s_mbar0_ras_unc_cxl_ide_tx_error,
    output  s_mbar0_ras_unc_cxl_ide_rx_error,    
    output  s_mbar0_ras_corr_cache_data_ecc,
    output  s_mbar0_ras_corr_mem_data_ecc,
    output  s_mbar0_ras_corr_crc_threshold,
    output  s_mbar0_ras_corr_retry_threshold,
    output  s_mbar0_ras_corr_cache_poison_received,
    output  s_mbar0_ras_corr_mem_poison_received,
    output  s_mbar0_ras_corr_physical_layer_error,
    output  s_mbar0_ras_header_log_reg0,
    output  s_mbar0_ras_header_log_reg1,
    output  s_mbar0_ras_header_log_reg2,
    output  s_mbar0_ras_header_log_reg3,
    output  s_mbar0_ras_header_log_reg4,
    output  s_mbar0_ras_header_log_reg5,
    output  s_mbar0_ras_header_log_reg6,
    output  s_mbar0_ras_header_log_reg7,
    output  s_mbar0_ras_header_log_reg8,
    output  s_mbar0_ras_header_log_reg9,
    output  s_mbar0_ras_header_log_reg10,
    output  s_mbar0_ras_header_log_reg11,
    output  s_mbar0_ras_header_log_reg12,
    output  s_mbar0_ras_header_log_reg13,
    output  s_mbar0_ras_header_log_reg14,
    output  s_mbar0_ras_header_log_reg15,
    output  s_mbar0_link_ver_received,
    output  s_mbar0_link_llr_wrap_val_received,
    output  s_mbar0_link_num_retry_received,
    output  s_mbar0_link_num_phy_reinit_received,
    output  s_mbar0_link_wr_ptr_received,
    output  s_mbar0_link_echo_eseq_received,
    output  s_mbar0_link_num_free_buf_received,
    output  s_mbar0_link_ll_reset_clr,
    output  s_mbar0_link_init_state,
    output  s_mbar0_link_ll_retry_buffer_consumed,
    output  s_mbar0_link_rx_cache_req_credits_stat,
    output  s_mbar0_link_rx_cache_rsp_credits_stat,
    output  s_mbar0_link_rx_cache_data_credits_stat,
    output  s_mbar0_link_rx_mem_req_rsp_credits_stat,
    output  s_mbar0_link_rx_mem_data_credits_stat,
    output  s_mbar0_link_tx_cache_req_credits_stat,
    output  s_mbar0_link_tx_cache_rsp_credits_stat,
    output  s_mbar0_link_tx_cache_data_credits_stat,
    output  s_mbar0_link_tx_mem_req_rsp_credits_stat,
    output  s_mbar0_link_tx_mem_data_credits_stat,
    output  s_mbar0_link_rx_mem_bi_credits_stat,
    output  s_mbar0_link_tx_mem_bi_credits_stat,
    output  s_pl_reg_lrsm_state,
    output  s_pl_reg_lrsm_fatal_error,
    output  s_pl_reg_cm_ll_cache_poison_injection_busy,
    output  s_pl_reg_cm_ll_mem_poison_injection_busy,
    output  s_pl_reg_cm_ll_cache_mem_crc_injection_busy,
    output  s_pl_reg_fatal_error,
    output  s_cfg_cxl_pl_reg_viral_status_set,
    output  s_cfg_cxl_dev_viral_status_set,
    output  s_ras_dp_err_log,
    input   s_ras_dp_err_inj,
    input   s_cfg_cxl_port_cache_capable,
    input   s_cfg_cxl_port_mem_capable,
    input   s_cfg_cxl_port_vid,
    input   s_cfg_cxl_port_68B_flit_vh_capable,      
    input   s_cfg_cxl_port_mld_capable,         
    input   s_cfg_cxl_port_lopt_flit_capable,
    input   s_cfg_cxl_port_pbr_flit_capable,
    input   s_cfg_cxl_port_nop_hint_capable,
    input   s_cfg_cxl_port_68B_flit_vh_enable,       
    input   s_cfg_cxl_port_mld_enable,          
    input   s_cfg_cxl_port_lopt_flit_enable,
    input   s_cfg_cxl_port_pbr_flit_enable,
    input   s_cfg_cxl_port_nop_hint_enable,
    input   s_cfg_cxl_port_disable_cxl1p1_training, 
    input   s_cfg_cxl_port_cache_enable,
    input   s_cfg_cxl_port_io_enable,
    input   s_cfg_cxl_port_mem_enable,
    input   s_cfg_cxl_port_sync_hdr_bypass_enable,
    input   s_cfg_cxl_port_drift_buffer_enable,
    input   s_cfg_cxl_port_retimer1_present,
    input   s_cfg_cxl_port_retimer2_present,
    input   s_cfg_cxl_port_retimers_pre_mismatched,
    input   s_cfg_cxl_viral_enable,
    input   s_cfg_cxl_viral_status,
    input   s_cfg_cxl_pl_reg_viral_status,
    input   s_cfg_cxl_dev_io_enable,
    input   s_cfg_cxl_dev_cache_enable,
    input   s_cfg_cxl_dev_mem_enable,
    input   s_cfg_cxl_dev_cache_sf_coverage,
    input   s_cfg_cxl_dev_cache_sf_granularity,
    input   s_cfg_cxl_dev_cache_clean_eviction,
    input   s_cfg_cxl_dev_viral_enable,
    input   s_cfg_cxl_dev_cxl_rst_mem_clr_enable,
    input   s_cfg_cxl_dev_post_cold_rst_volatile_hdm_default,
    input   s_cfg_cxl_dev_post_warm_rst_volatile_hdm_default,
    input   s_cfg_cxl_dev_post_hot_rst_volatile_hdm_default,
    input   s_cfg_cxl_dev_post_hot_rst_volatile_hdm_desired,
    input   s_cfg_cxl_dev_viral_status,
    input   s_cfg_cxl_dev_disable_caching, 
    input   s_cfg_cxl_dev_initiate_cache_wr_invld, 
    input   s_cfg_cxl_dev_initiate_cxl_rst, 
    input   s_cfg_cxl_dev_range1_mem_size_high,      
    input   s_cfg_cxl_dev_range1_mem_info_valid,     
    input   s_cfg_cxl_dev_range1_mem_active,         
    input   s_cfg_cxl_dev_range1_desired_interleave,
    input   s_cfg_cxl_dev_range1_mem_active_timeout,
    input   s_cfg_cxl_dev_range1_mem_size_low,    
    input   s_cfg_cxl_dev_range1_mem_base_high,
    input   s_cfg_cxl_dev_range1_mem_base_low,
    input   s_cfg_cxl_dev_range2_mem_size_high,      
    input   s_cfg_cxl_dev_range2_mem_info_valid,     
    input   s_cfg_cxl_dev_range2_mem_active,         
    input   s_cfg_cxl_dev_range2_desired_interleave,
    input   s_cfg_cxl_dev_range2_mem_active_timeout,
    input   s_cfg_cxl_dev_range2_mem_size_low,     
    input   s_cfg_cxl_dev_range2_mem_base_high,
    input   s_cfg_cxl_dev_range2_mem_base_low,
    input   s_mbar0_ras_uncorr_error_mask,
    input   s_mbar0_ras_uncorr_error_severity, 
    input   s_mbar0_ras_corr_error_mask,
    input   s_mbar0_ras_poison_enabled,
    input   s_mbar0_security_device_trust_level,
    input   s_mbar0_link_ver_supported,
    input   s_mbar0_link_llr_wrap_val_supported,
    input   s_mbar0_link_ll_reset,
    input   s_mbar0_link_ll_init_stall,
    input   s_mbar0_link_ll_crd_stall,
    input   s_mbar0_link_rx_cache_req_credits,
    input   s_mbar0_link_rx_cache_rsp_credits,
    input   s_mbar0_link_rx_cache_data_credits,
    input   s_mbar0_link_rx_mem_req_rsp_credits,
    input   s_mbar0_link_rx_mem_data_credits,
    input   s_mbar0_link_rx_mem_bi_credits,
    input   s_mbar0_link_ack_force_threshold,
    input   s_mbar0_link_ack_flush_retimer,
    input   s_mbar0_link_mdh_disable,
    input   s_mbar0_arb_mux_cxl_io,
    input   s_mbar0_arb_mux_cxl_cache_mem,
    input   s_mbar0_cap_header_reg,
    input   s_mbar0_ras_cap_header_reg,
    input   s_mbar0_security_cap_header_reg,
    input   s_mbar0_link_cap_header_reg,
    input   s_mbar0_ras_corr_reg,
    input   s_mbar0_ras_uncorr_reg,
    input   s_cxl_fatal_error_reg,    
    input   s_pl_reg_vlsm_pm_enable,
    input   s_pl_reg_apn_bypass_enable,
    input   s_pl_reg_apn_sw_mode,
    input   s_pl_reg_vlsm_to_active,
    input   s_pl_reg_max_num_retry,
    input   s_pl_reg_max_num_reinit,
    input   s_pl_reg_lrsm_timeout_threshold,
    input   s_pl_reg_crc_threshold
   ,input   s_pl_reg_cm_ll_cache_poison_injection_start,
    input   s_pl_reg_cm_ll_mem_poison_injection_start,
    input   s_pl_reg_cm_ll_cache_mem_crc_injection,
    input   s_pl_reg_cm_ll_cache_mem_crc_injection_count
   ,input  s_cfg_cxl_2_0_ext_viral_status,              // Switch Port has entered Viral
    input  s_cfg_cxl_2_0_ext_viral_en                  // Viral Enable for Switch
  );


endinterface : DWC_cxl_cdmregs_if

`endif // __GUARD__DWC_CXL_CDMREGS_IF__SVH__
