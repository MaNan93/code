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
// ---  RCS information:
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #38 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_ecfg_reg.sv#38 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the decoding of PCIE extended capability registers
// --- and Virtual Channel extended capability structure
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

 module cdm_ecfg_reg
 import DWC_pcie_ctl_pkg::MSG_TLP_WD;
 import DWC_pcie_ctl_pkg::ERROR_TLP_WD;
import DWC_pcie_core_pkg::latency_tracking_status_e;
(
// -- inputs ---
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    cdm_clk_g,
    device_type,
    lbc_cdm_addr,
    lbc_cdm_data,
    lbc_cdm_wr,
    lbc_cdm_dbi,
    lbc_cdm_dbi2,
    err_reg_data,
    ecfg_reg_sel,
    ras_reg_ack,
    ras_reg_data,
    cfg_ras_reg_pf0_only,
    spcie_reg_data,
    pl16g_reg_data,
    margin_reg_data,
    pl32g_reg_data,
    pl64g_reg_data,
    l1sub_reg_data,

    dev3_reg_data,
    rasdes_reg_sel,
    rasdes_reg_id,
    rtlh_fc_init_status,
    cfg_pwr_budget_data_reg,
    cfg_pwr_budget_func_num,
    dbi_ro_wr_en,

    cfg_msi_en,
    cfg_msix_en,
    radm_drs_msg,
    radm_msg_req_id,
    cfg_downstream_comp_pres,
    radm_frs_msg,
    radm_frs_msg_reason,
    cfg_pbus_num,
    cfg_pbus_dev_num,
    pmstate_d3hot_to_d0,
    cfg_drs_frs_sig_en,

    rasdes_reg_data,
    rasdes_reg_ack,
    cfg_rasdes_reg_pf0_only,
    ptm_vsec_reg_data,
    ptm_reg_data,
    vsecdma_reg_data,
    upstream_port,
    rdlh_link_up,

    prs_res_failure,
    prs_uprgi,
    prs_stopped,
    int_dpc_triggered,
    int_dpc_trig_reason,
    int_dpc_trig_reason_extn,
    dpc_err_src_id,
    cfg_int_disable,
    cxl_rcrb_enable,
    cxl2p0_enabled,
    cxl_mld_enabled,
    cxl_reg_data,
    cxl_rcrb_reg_data,
    cxl_mbar0_reg_sel,
    lbc_cdm_rcrb_dbi,
    cxl_2_0_ext_reg_data,
    cxl_reg_locator_reg_data,
    cxl_gpf_port_reg_data,
    cxl_gpf_device_reg_data,
    cfg_pcie_cap_flit_mode_sup,
// -- outputs --
    ecfg_write_pulse,
    ecfg_read_pulse,
    ecfg_reg_data,
    ecfg_reg_ack,
    err_reg_id,
    ras_reg_sel,
    ras_reg_id,
    spcie_reg_id,
    pl16g_reg_id,
    margin_reg_id,
    pl32g_reg_id,
    pl64g_reg_id,
    l1sub_reg_id,
    dev3_reg_id,
    cfg_tph_req_en,
    cfg_pf_tph_st_mode,
    frsq_msi,
    frsq_int_msg_num,
    cfg_ats_stu,
    cfg_ats_cache_en,

    cfg_acs_validation_cap,
    cfg_acs_at_blocking_cap,
    cfg_acs_up_forward_cap,
    cfg_acs_p2p_req_redirect_cap,
    cfg_acs_p2p_compl_redirect_cap,
    cfg_acs_p2p_egress_ctrl_cap,
    cfg_acs_p2p_direct_transl_cap,
    cfg_acs_egress_ctrl_vector_size_cap,
    cfg_acs_validation_en,
    cfg_acs_at_blocking_en,
    cfg_acs_p2p_req_redirect_en,
    cfg_acs_p2p_compl_redirect_en,
    cfg_acs_up_forward_en,
    cfg_acs_p2p_egress_ctrl_en,
    cfg_acs_p2p_direct_transl_en,
    cfg_acs_egress_ctrl_vec,
    acs_viol_svrity_mask_wr_en,    // Indicates that ACS Violation Severity and Mask fields are writable
    cfg_prs_enable,
    cfg_prs_reset,
    cfg_prs_stopped,
    cfg_prs_uprgi,
    cfg_prs_response_failure,
    cfg_prs_outstanding_allocation,
    cfg_ltr_max_latency,
    cfg_vc_enable,
    cfg_vc_struc_vc_id_map,
    cfg_vc_id_vc_struc_map,
    cfg_tc_enable,
    cfg_tc_vc_map,
    cfg_tc_vc_struc_map,
    cfg_lpvc,
    cfg_vc_arb_sel,
    cfg_pwr_budget_data_sel_reg,
    cfg_pwr_budget_sel,
    cfg_rbar_bar_resizable,
    cfg_rbar_bar0_mask,
    cfg_rbar_bar1_mask,
    cfg_rbar_bar2_mask,
    cfg_rbar_bar3_mask,
    cfg_rbar_bar4_mask,
    cfg_rbar_bar5_mask,
    cfg_vf_rbar_bar_resizable,
    cfg_vf_rbar_bar0_mask,
    cfg_vf_rbar_bar1_mask,
    cfg_vf_rbar_bar2_mask,
    cfg_vf_rbar_bar3_mask,
    cfg_vf_rbar_bar4_mask,
    cfg_vf_rbar_bar5_mask,
    cfg_pf_pasid_control,

    ptm_vsec_reg_id,
    vsecdma_reg_sel,
    vsecdma_reg_id,
    rdlh_rcvd_dl_feature,
    rcvd_dl_feature_content,
    cfg_local_feature_support,
    cfg_remote_feature_support,
    cfg_dlink_feature_valid,
    dl_feature_en,
    cfg_remote_feature_ack,
    fc_scaled_en,
    rdlh_dlcntrl_state,
    cfg_dpc_int_msg_num,
    cfg_dpc_rp_ext_dpc,
    cfg_dpc_poison_tlp_egr_blk_support,
    cfg_dpc_sw_trig_support,
    cfg_dpc_rp_pio_log_size,
    cfg_dpc_dl_active_err_cor_support,
    cfg_dpc_trig_en,
    cfg_dpc_trig_status,
    dpc_triggered_detect,
    dpc_int,
    dpc_msi,
    cfg_dpc_cpl_cntrl,
    cfg_dpc_int_en,
    cfg_dpc_err_cor_en,
    cfg_dpc_poison_tlp_egr_block_en,
    cfg_dpc_sw_trigger,
    cfg_dpc_dl_active_err_cor_en,
    rbar_ctrl_update,
    cfg_rbar_size,
    vf_rbar_ctrl_update,
    cfg_vf_rbar_size
   ,cxl_reg_id
   ,cxl_rcrb_reg_id
   ,cxl_mbar0_write_pulse
   ,cxl_mbar0_reg_ack
   ,cxl_mbar0_cache_mem_reg_id
   ,cxl_mbar0_arb_mux_reg_id
   ,cxl_2_0_ext_reg_id
   ,cxl_reg_locator_reg_id
   ,cxl_gpf_port_reg_id
   ,cxl_gpf_device_reg_id
   ,cfg_flit_log              
   ,cfg_link_wd_err_cnt_start 
   ,cfg_flit_err_cnt          
   ,cfg_flit_cnt              
   ,cfg_invalid_flit_cnt      
   ,cfg_interr_trg_evnt_cnt  
   ,cfg_interr_trg_evnt_cnt_clr   
   ,cfg_lane_0_corr_cnt       
   ,cfg_lane_1_corr_cnt       
   ,cfg_lane_2_corr_cnt       
   ,cfg_lane_3_corr_cnt       
   ,cfg_lane_4_corr_cnt       
   ,cfg_lane_5_corr_cnt       
   ,cfg_lane_6_corr_cnt       
   ,cfg_lane_7_corr_cnt       
   ,cfg_lane_8_corr_cnt       
   ,cfg_lane_9_corr_cnt       
   ,cfg_lane_10_corr_cnt      
   ,cfg_lane_11_corr_cnt      
   ,cfg_lane_12_corr_cnt      
   ,cfg_lane_13_corr_cnt      
   ,cfg_lane_14_corr_cnt      
   ,cfg_lane_15_corr_cnt         
   ,cfg_trg_evnt_cnt                  
   ,cfg_evnt_to_cnt                   
   ,cfg_flit_err_cnt_en               
   ,cfg_interr_trg_evnt_cnt_ind    
   ,cfg_fber_measurement_en           
   ,cfg_clr_fber_cnt                  
   ,cfg_gran_per_lane_err_rpt         
   ,cfg_rpt_longest_burst_vs_1st_burst  
   ,cfg_flit_log_trg_evnt_msi
   ,cfg_pop_fifo_en   

    ,cfg_flit_latency_status 
    ,cfg_flit_latency_value
    ,cfg_ltssm_st_trans1_status
    ,cfg_ltssm_st_trans2_status
    ,cfg_ltssm_st_trans3_status
    ,cfg_ltssm_st_trans4_status
    ,cfg_ltssm_st_trans5_status
    ,cfg_ltssm_st_trans_latency
    ,cfg_msi_en_pf0 
    ,cfg_msix_en_pf0
    ,cfg_flit_perf_interr_vec
    ,cfg_ltssm_trck_reg_cnt
    ,cfg_flit_response_type
    ,cfg_flit_type_measured
    ,cfg_track_mode
    ,cfg_Ltssm_st_trans_trck
    ,cfg_trg_evnt_interr
    ,cfg_flit_latency_msi                     
    ,cfg_sts_1_ltssm_trg_evnt_interr    
    ,cfg_sts_1_ltssm_latency_msi    

    ,cfg_inj_err_num                        
    ,cfg_flit_type_inj                      
    ,cfg_flit_err_tx_inj_sts                
    ,cfg_flit_err_rx_inj_sts                   
    ,cfg_ordr_set_tx_inj_sts_ts0            
    ,cfg_ordr_set_tx_inj_sts_ts1            
    ,cfg_ordr_set_tx_inj_sts_ts2            
    ,cfg_ordr_set_tx_inj_sts_skp            
    ,cfg_ordr_set_tx_inj_sts_eieos          
    ,cfg_ordr_set_tx_inj_sts_eios           
    ,cfg_ordr_set_tx_inj_sts_sds            
    ,cfg_ordr_set_tx_inj_sts_poll           
    ,cfg_ordr_set_tx_inj_sts_cfg            
    ,cfg_ordr_set_tx_inj_sts_l0             
    ,cfg_ordr_set_tx_inj_sts_non_eq_recov   
    ,cfg_ordr_set_tx_inj_sts_recov_eq_ph_1_0
    ,cfg_ordr_set_tx_inj_sts_recov_eq_ph_2  
    ,cfg_ordr_set_tx_inj_sts_recov_eq_ph_3  
    ,cfg_ordr_set_rx_inj_sts_ts0            
    ,cfg_ordr_set_rx_inj_sts_ts1            
    ,cfg_ordr_set_rx_inj_sts_ts2            
    ,cfg_ordr_set_rx_inj_sts_skp            
    ,cfg_ordr_set_rx_inj_sts_eieos          
    ,cfg_ordr_set_rx_inj_sts_eios           
    ,cfg_ordr_set_rx_inj_sts_sds            
    ,cfg_ordr_set_rx_inj_sts_poll           
    ,cfg_ordr_set_rx_inj_sts_cfg            
    ,cfg_ordr_set_rx_inj_sts_l0             
    ,cfg_ordr_set_rx_inj_sts_non_eq_recov   
    ,cfg_ordr_set_rx_inj_sts_recov_eq_ph_1_0
    ,cfg_ordr_set_rx_inj_sts_recov_eq_ph_2  
    ,cfg_ordr_set_rx_inj_sts_recov_eq_ph_3  

    ,cfg_flit_err_inj_en                    
    ,cfg_inj_err_tx_flit_ind                
    ,cfg_inj_err_rx_flit_ind                
    ,cfg_flit_err_inj_en_data_rate          
    ,cfg_inj_err_spacing                    
    ,cfg_consec_err_inj                     
    ,cfg_curr_inj_err_type                  
    ,cfg_flit_err_off                       
    ,cfg_err_mag                 
    ,cfg_ordr_set_err_inj_en                
    ,cfg_inj_err_tx_ordr_set_ind            
    ,cfg_inj_err_rx_ordr_set_ind            
    ,cfg_ordr_set_inj_err_num               
    ,cfg_ordr_set_inj_err_spacing           
    ,cfg_inj_err_ts0_os                     
    ,cfg_inj_err_ts1_os                     
    ,cfg_inj_err_ts2_os                     
    ,cfg_inj_err_skp_os                     
    ,cfg_inj_err_eieos_os                   
    ,cfg_inj_err_eios_os                    
    ,cfg_inj_err_sds_os                     
    ,cfg_inj_err_poll_st                    
    ,cfg_inj_err_cfg_st                     
    ,cfg_inj_err_l0_st                      
    ,cfg_inj_err_non_eq_recov_st            
    ,cfg_inj_err_recov_eq_ph_1_0            
    ,cfg_inj_err_recov_eq_ph_2              
    ,cfg_inj_err_recov_eq_ph_3              
    ,cfg_err_inj_bytes                      
    ,cfg_err_inj_lane_num              

);

parameter RCRB       = 0;                            // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space
parameter NCXL_MEMBAR0_CACHE_MEM  = `CXL_RCRB_MEMBAR0_CACHE_MEM_CAP_SIZE + 'd4 ; // Number of registers in CXL RCRB MEMBAR0
parameter NCXL_MEMBAR0_ARB_MUX    = `CXL_RCRB_MEMBAR0_ARB_MUX_SIZE ;       // Number of registers in CXL RCRB MEMBAR0
parameter INST       = 0;                            // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM   = 0;                            // uniquifying parameter per function
parameter TP         = `TP;                          // Clock to Q delay (simulator insurance)
parameter NL         = `CX_NL;                       // Number of Lanes Supported
parameter NFUNC_WD   = `CX_NFUNC_WD;                 // Width of physical function number
parameter NVC        = `CX_NVC;                      // Number of VC channels supported
parameter VC_EN      = `VC_ENABLE;                   // VC Capability enabled or not
parameter AER_EN     = `AER_ENABLE;                  // AER Capability enabled or not
parameter SN_EN      = `SERIAL_CAP_ENABLE;           // Device Serial Number Capability enabled or not
parameter PB_EN      = `PWR_BUDGET_CAP_ENABLE;       // Power Budgeting Capability enabled or not
parameter SRIOV_EN   = `CX_SRIOV_ENABLE_VALUE;       // SR-IOV Capability enabled or not
parameter ARI_EN_VAL = `CX_ARI_ENABLE_VALUE;         // ARI Capability enabled or not
parameter SPCIE_EN   = `SPCIE_CAP_ENABLE_VALUE;      // Secondary PCIe Extended Capability Enabled or not
parameter PL16G_EN   = `CX_PL16G_ENABLE_VALUE;       // Physical Layer 16.0 GT/s Extended Capability Enabled or not
parameter MARGIN_EN  = `CX_MARGIN_ENABLE_VALUE;      // Margining Extended Capability Enabled or not
parameter ACS_CTRL_VEC_WD = `ACS_CTRL_VEC_WD;        // ACS Control Vector Width
parameter CIO_EN         = `CX_PCIE_MODE == `PCIE_OVER_CIO;

parameter NPTMVSEC = CIO_EN ? 31 : 26;  // Number of PTM Requester or PTM Responder VSEC Registers, whichever is greater
localparam NSPCIE    = `SPCIE_SIZE >> 2 ;             // Number of registers in Secondary PCIe Extended Capability Structure
localparam NPL16G    = `PL16G_SIZE >> 2 ;             // Number of registers in Physical Layer 16.0 GT/s Extended Capability Structure
localparam NPL32G    = `PL32G_SIZE >> 2 ;             // Number of registers in Physical Layer 32.0 GT/s Extended Capability Structure
localparam NPL64G    = `PL64G_SIZE >> 2 ;             // Number of registers in Physical Layer 32.0 GT/s Extended Capability Structure
localparam NMARGIN    = `MARGIN_SIZE >> 2 ;          // Number of registers in Margining Extended Capability Structure
localparam NL1SUB    = 4;                            // Number of registers in L1 Substates Extended Capability Structure
localparam NPASID    = 2;                            // Number of 32-bit registers in PASID Extended Capability Structure
localparam NRTR = 3;
parameter NDPC    =    17
                          ;                           // Max possible number of registers in DPC Extended Capability Structure (17/23 which includes all RP PIO)
parameter DPC_PRFX_LOG_SIZE = `CX_MAX_DPC_RPPIO_PRFXS_VALUE;           // Prefix log in DWs.
parameter DPC_PRFX_LOG_WD   = 32*DPC_PRFX_LOG_SIZE;                    // Prefix log width in bits.
localparam FLITLOGGING   = `FLIT_LOGGING_SIZE >> 2;               // Number of registers in Flit Logging Extended Capability Structure

localparam FLIT_PERF_MEASUREMENT = `FLIT_PERF_MEASUREMENT_SIZE >> 2 ; // Number of registers in Flit Performance Measurement Extended Capability Structure

localparam FLIT_ERR_INJ = `FLIT_ERR_INJ_SIZE >> 2 ;  // Number of registers in Flit Error Injection Extended Capability Structure

localparam PTM_REQ_VALUE = `CX_PTM_REQUESTER_VALUE;

localparam NPTM = 3;



//`ifdef CX_RN_FRSQ_ENABLE
localparam NFRSQ = 4;
//`endif //CX_RN_FRSQ_ENABLE


localparam NF        = `CX_NFUNC;                  // Number of functions
localparam FX_TLP    = `CX_FX_TLP;                 // Number of TLPs received in a single cycle after formation block
localparam PB_NF     = `CX_PB_NFUNC;               // Number of functions for PB Cap
localparam DSN_NF    = `CX_DSN_NFUNC;              // Number of functions for DSN Cap


localparam NR_RAS_REGS     = 25;                            // Number of registers (4 bytes)
localparam FLIT_MODE_ENABLE           = `CX_FLIT_MODE_SUPPORTED;
localparam ERR_REG_ID_WD = (FLIT_MODE_ENABLE == 1)? 




  1? 19:
                                                    18 : 18;


// ----- Inputs ---------------
input                   core_clk;
input                   non_sticky_rst_n;
input                   sticky_rst_n;
input                   cdm_clk_g;              // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input   [3:0]           device_type;                // Device type
input   [15:0]          lbc_cdm_addr;               // Address of resource being accessed
input   [31:0]          lbc_cdm_data;               // Data for write
input   [3:0]           lbc_cdm_wr;                 // byte Write select
input                   lbc_cdm_dbi;                // DBI access to CDM
input                   lbc_cdm_dbi2;                // DBI access to CDM
input                   ecfg_reg_sel;               // ecfg registers selected
input   [31:0]          err_reg_data;               // error register read
input                   ras_reg_ack;                // RAS Extended Capability read acknowledge
input   [31:0]          ras_reg_data;               // RAS Extended Capability read data
input                   cfg_ras_reg_pf0_only;       // When asserted, it blocks PFs access other than PF0 to RAS Extended Capability.
input  [31:0]           spcie_reg_data;             // SPCIE register read data
input  [31:0]           pl16g_reg_data;             // Physical Layer 16GT/s register read data
input  [31:0]           margin_reg_data;            // Margining register read data
input  [31:0]           pl32g_reg_data;             // Physical Layer 32GT/s register read data
input  [31:0]           pl64g_reg_data;             // Physical Layer 64GT/s register read data
input  [31:0]           l1sub_reg_data;             // L1 Substates register read data
input   [31:0]          dev3_reg_data;              // DEV3 register read data
input   [NVC-1:0]       rtlh_fc_init_status;        // indicates the status of the process of FC initialization
input   [31:0]          cfg_pwr_budget_data_reg;    // Data Register from application
input   [NFUNC_WD-1:0]  cfg_pwr_budget_func_num;    // Function # of data register above
input                   dbi_ro_wr_en;
input   [31:0]          rasdes_reg_data;            // RAS DES register read data
input                   rasdes_reg_ack;             // RAS DES register ack
input                   cfg_rasdes_reg_pf0_only;    // When asserted, it blocks PFs access other than PF0 to RAS DES Extended Capability.

input                   cfg_msi_en;
input                   cfg_msix_en;
input [MSG_TLP_WD-1:0]      radm_drs_msg;
wire  [MSG_TLP_WD-1:0]      radm_drs_msg;
input [(MSG_TLP_WD*16)-1:0] radm_msg_req_id;
wire  [(MSG_TLP_WD*16)-1:0] radm_msg_req_id;
input [2:0]             cfg_downstream_comp_pres;
input [MSG_TLP_WD-1:0]      radm_frs_msg;
wire  [MSG_TLP_WD-1:0]      radm_frs_msg;
input [(MSG_TLP_WD*4)-1:0]  radm_frs_msg_reason;
wire  [(MSG_TLP_WD*4)-1:0]  radm_frs_msg_reason;
input                   pmstate_d3hot_to_d0;
input [7:0]             cfg_pbus_num;
input [4:0]             cfg_pbus_dev_num;
input                   cfg_drs_frs_sig_en;

input [31:0]            ptm_vsec_reg_data;
input [31:0]            ptm_reg_data;
input [31:0]            vsecdma_reg_data;
input                   upstream_port;
input                   rdlh_link_up;

input                   prs_res_failure;
wire                    prs_res_failure;
input                   prs_uprgi;
wire                    prs_uprgi;
input                   prs_stopped;
wire                    prs_stopped;
input                   rdlh_rcvd_dl_feature;
input [31:0]            rcvd_dl_feature_content;
input [1:0]             rdlh_dlcntrl_state;
input                   int_dpc_triggered;
input    [1:0]          int_dpc_trig_reason;
input    [1:0]          int_dpc_trig_reason_extn;
input  [15:0]           dpc_err_src_id;          // DPC Error Source ID.
input                   cfg_int_disable;         // Interrupt Disable field of Command Register.

input                   cxl_rcrb_enable;            // Indicates that the CXL 1.1 Link is up for USP supporting RCRB
input                   cxl2p0_enabled;             // Indicates CXL 2.0 linkup
input                   cxl_mld_enabled;            // CXL MLD negotiation is successful
input  [31:0]           cxl_reg_data;               // Data read from Flex Bus Device DVSEC register
input  [31:0]           cxl_rcrb_reg_data;          // Data read from Flex Bus Port DVSEC register
input                   cxl_mbar0_reg_sel;          // access cxl rcrb membar0 registers
input                   lbc_cdm_rcrb_dbi;
output [14:0]           cxl_reg_id;                 // Register select for the Flex Bus Device DVSEC
output [7:0]            cxl_rcrb_reg_id;            // Register select for the Flex Bus Port DVSEC
output [3:0]            cxl_mbar0_write_pulse;      //CXL RCRB MEMBAR0 Write Pulse
output                  cxl_mbar0_reg_ack;          //CXL RCRB MEMBAR0 Acknowledge back from core. Indicates completion, read data is valid
output [NCXL_MEMBAR0_CACHE_MEM-1:0] cxl_mbar0_cache_mem_reg_id;// Register select for RCRB MEMBAR0 CACHE MEM
output   [NCXL_MEMBAR0_ARB_MUX-1:0] cxl_mbar0_arb_mux_reg_id;// Register select for RCRB MEMBAR0 ARB/MUX

output [9:0]            cxl_2_0_ext_reg_id;           // Register select for CXL 2.0 Extension DVSEC
input  [31:0]           cxl_2_0_ext_reg_data;         // Read data from CXL 2.0 Extension DVSEC
output [8:0]            cxl_reg_locator_reg_id;       // Register select for CXL Register Locator DVSEC
input  [31:0]           cxl_reg_locator_reg_data;     // Read data from CXL Register Locator DVSEC
output [3:0]            cxl_gpf_port_reg_id;        // Register select for CXL PORT GPF DVSEC
input  [31:0]           cxl_gpf_port_reg_data;      // Read data from CXL PORT GPF DVSEC
output [3:0]            cxl_gpf_device_reg_id;        // Register select for CXL DEVICE GPF DVSEC
input  [31:0]           cxl_gpf_device_reg_data;      // Read data from CXL DEVICE GPF DVSEC
input                   cfg_pcie_cap_flit_mode_sup ;  // Flit Mode Supported Bit
input  [63:0]           cfg_flit_log               ;
input  [2:0]            cfg_link_wd_err_cnt_start  ;
input  [7:0]            cfg_flit_err_cnt           ;
input  [31:0]           cfg_flit_cnt               ;
input  [15:0]           cfg_invalid_flit_cnt       ;
input                   cfg_interr_trg_evnt_cnt    ;
input                   cfg_interr_trg_evnt_cnt_clr;
input  [15:0]           cfg_lane_0_corr_cnt        ;
input  [15:0]           cfg_lane_1_corr_cnt        ;
input  [15:0]           cfg_lane_2_corr_cnt        ;
input  [15:0]           cfg_lane_3_corr_cnt        ;
input  [15:0]           cfg_lane_4_corr_cnt        ;
input  [15:0]           cfg_lane_5_corr_cnt        ;
input  [15:0]           cfg_lane_6_corr_cnt        ;
input  [15:0]           cfg_lane_7_corr_cnt        ;
input  [15:0]           cfg_lane_8_corr_cnt        ;
input  [15:0]           cfg_lane_9_corr_cnt        ;
input  [15:0]           cfg_lane_10_corr_cnt       ;
input  [15:0]           cfg_lane_11_corr_cnt       ;
input  [15:0]           cfg_lane_12_corr_cnt       ;
input  [15:0]           cfg_lane_13_corr_cnt       ;
input  [15:0]           cfg_lane_14_corr_cnt       ;
input  [15:0]           cfg_lane_15_corr_cnt       ;

input  latency_tracking_status_e  cfg_flit_latency_status              ;
input  [15:0]                     cfg_flit_latency_value               ;
input  latency_tracking_status_e  cfg_ltssm_st_trans1_status           ;
input  latency_tracking_status_e  cfg_ltssm_st_trans2_status           ;
input  latency_tracking_status_e  cfg_ltssm_st_trans3_status           ;
input  latency_tracking_status_e  cfg_ltssm_st_trans4_status           ;
input  latency_tracking_status_e  cfg_ltssm_st_trans5_status           ;
input  [15:0]                     cfg_ltssm_st_trans_latency           ;
input                             cfg_msi_en_pf0                       ;
input                             cfg_msix_en_pf0                      ;


input [1:0]                        cfg_flit_err_tx_inj_sts                         ;
input [1:0]                        cfg_flit_err_rx_inj_sts                         ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_ts0                     ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_ts1                     ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_ts2                     ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_skp                     ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_eieos                   ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_eios                    ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_sds                     ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_poll                    ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_cfg                     ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_l0                      ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_non_eq_recov            ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_recov_eq_ph_1_0         ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_recov_eq_ph_2           ;
input [1:0]                        cfg_ordr_set_tx_inj_sts_recov_eq_ph_3           ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_ts0                     ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_ts1                     ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_ts2                     ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_skp                     ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_eieos                   ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_eios                    ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_sds                     ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_poll                    ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_cfg                     ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_l0                      ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_non_eq_recov            ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_recov_eq_ph_1_0         ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_recov_eq_ph_2           ;
input [1:0]                        cfg_ordr_set_rx_inj_sts_recov_eq_ph_3           ;


// ----- Outputs ---------------
output  [3:0]           ecfg_write_pulse;           // Extended Capability Write pulse
output                  ecfg_read_pulse;            // Extended Capability Read pulse
output  [ERR_REG_ID_WD-1:0] err_reg_id;             // Adv. Error Register #
output  [31:0]          ecfg_reg_data;              // Read data back from core
output                  ecfg_reg_ack;               // Acknowledge back from core. Indicates completion, read data is valid
output                  ras_reg_sel;                // RAS Select
output [NR_RAS_REGS-1:0] ras_reg_id;                 // RAS Register #
output   [NSPCIE-1:0]   spcie_reg_id;               // SPCIE Register #
output   [NPL16G-1:0]   pl16g_reg_id;               // Physical Layer 16GT/s Register #
output   [NMARGIN-1:0]  margin_reg_id;              // Margining Register #
output   [NPL32G-1:0]   pl32g_reg_id;               // Physical Layer 32GT/s Register #
output   [NPL64G-1:0]   pl64g_reg_id;               // Physical Layer 64GT/s Register #
output   [NL1SUB-1:0]   l1sub_reg_id;               // L1 Substates Register #
output  [3:0]           dev3_reg_id;                // DEV3 Register #
output                  rasdes_reg_sel;              // RASDES Select
output  [63:0]          rasdes_reg_id;               // RASDES Register #
output  [1:0]           cfg_tph_req_en;             // TPH Requester Enable
output  [2:0]           cfg_pf_tph_st_mode;
output                  frsq_msi;                         // MSI or MSI-X pulse
output  [4:0]           frsq_int_msg_num;                 // FRSQ Interrupt vector
wire                    frsq_msi;
wire    [4:0]           frsq_int_msg_num;
output  [NPTMVSEC-1:0]  ptm_vsec_reg_id;
output                  vsecdma_reg_sel;                // DMA VSEC Select
output  [5:0]           vsecdma_reg_id;                 // DMA VSEC Register #
output  [4:0]           cfg_ats_stu;                // ATS Smallest transfer Unit
output                  cfg_ats_cache_en;

output                 cfg_acs_validation_cap;
output                 cfg_acs_at_blocking_cap;
output                 cfg_acs_up_forward_cap;
output                 cfg_acs_p2p_req_redirect_cap;
output                 cfg_acs_p2p_compl_redirect_cap;
output                 cfg_acs_p2p_egress_ctrl_cap;
output                 cfg_acs_p2p_direct_transl_cap;
output [7:0]           cfg_acs_egress_ctrl_vector_size_cap;
output                 cfg_acs_validation_en;
output                 cfg_acs_at_blocking_en;
output                 cfg_acs_p2p_req_redirect_en;
output                 cfg_acs_p2p_compl_redirect_en;
output                 cfg_acs_up_forward_en;
output                 cfg_acs_p2p_egress_ctrl_en;
output                 cfg_acs_p2p_direct_transl_en;
output   [ACS_CTRL_VEC_WD-1:0] cfg_acs_egress_ctrl_vec;
output                 acs_viol_svrity_mask_wr_en;   // Indicates that ACS Violation Severity and Mask fields are writable

output                  cfg_prs_enable;             // Enable Page Request cabability
output                  cfg_prs_reset;              // Reset Page Request cabability
output                  cfg_prs_stopped;            // PRS Stopped
output                  cfg_prs_uprgi;              // Detected a Unexpected PRG Index
output                  cfg_prs_response_failure;   // Detected a Response Failure
output   [31:0]         cfg_prs_outstanding_allocation; // PRS Outstanding Allocation
 output [31:0]          cfg_ltr_max_latency;        // LTR Max Snoop & No-Snoop Latencies
output  [NVC-1:0]       cfg_vc_enable;              // Which VCs are enabled - VC0 is always enabled
output  [(NVC*3)-1:0]   cfg_vc_struc_vc_id_map;     // VC Structure to VC ID mapping
output  [23:0]          cfg_vc_id_vc_struc_map;     // VC ID to VC Structure mapping
output  [7:0]           cfg_tc_enable;              // Which TCs are enabled
output  [23:0]          cfg_tc_vc_map;              // TC to VC ID mapping
output  [23:0]          cfg_tc_vc_struc_map;        // TC to VC Structure mapping
output  [2:0]           cfg_lpvc;                   // Low Priority Extended VC (LPVC) Count
output  [2:0]           cfg_vc_arb_sel;             // VC Arbitration Select
output  [7:0]           cfg_pwr_budget_data_sel_reg;// Power Budgeting: Data Select register
output                  cfg_pwr_budget_sel;         // Power Budgeting: Pulse signal indicates new data_sel_reg
output [5:0]            cfg_rbar_bar_resizable;     // Resize RBAR[n] where n = 0 to 5
output [63:0]           cfg_rbar_bar0_mask;         // RBAR0 mask value
output [31:0]           cfg_rbar_bar1_mask;         // RBAR1 mask value
output [63:0]           cfg_rbar_bar2_mask;         // RBAR2 mask value
output [31:0]           cfg_rbar_bar3_mask;         // RBAR3 mask value
output [63:0]           cfg_rbar_bar4_mask;         // RBAR4 mask value
output [31:0]           cfg_rbar_bar5_mask;         // RBAR5 mask value
output                  rbar_ctrl_update;           // indicates that RBAR control register has been updated
output [(6*6)-1:0]      cfg_rbar_size;              // wire the BAR size fields to top level
output [5:0]            cfg_vf_rbar_bar_resizable;     // Resize VF RBAR[n] where n = 0 to 5
output [63:0]           cfg_vf_rbar_bar0_mask;         // VF RBAR0 mask value
output [31:0]           cfg_vf_rbar_bar1_mask;         // VF RBAR1 mask value
output [63:0]           cfg_vf_rbar_bar2_mask;         // VF RBAR2 mask value
output [31:0]           cfg_vf_rbar_bar3_mask;         // VF RBAR3 mask value
output [63:0]           cfg_vf_rbar_bar4_mask;         // VF RBAR4 mask value
output [31:0]           cfg_vf_rbar_bar5_mask;         // VF RBAR5 mask value
output                  vf_rbar_ctrl_update;           // indicates that VF RBAR control register has been updated
output [(6*6)-1:0]      cfg_vf_rbar_size;              // wire the VF BAR size fields to top level
output [`CX_PASID_CONTROL_WD-1:0] cfg_pf_pasid_control; // PF PASID control signal bus
output [22:0]           cfg_local_feature_support;
output [22:0]           cfg_remote_feature_support;
output                  cfg_dlink_feature_valid;
output                  dl_feature_en;
output                  cfg_remote_feature_ack;
output                  fc_scaled_en;
output [4:0]            cfg_dpc_int_msg_num;                  // DPC Interrupt Message Number
output                  cfg_dpc_rp_ext_dpc;                   // DPC Root Port Extensions for DPC
output                  cfg_dpc_poison_tlp_egr_blk_support;   // DPC Poisoned TLP Egress Blocking Supported
output                  cfg_dpc_sw_trig_support;              // DPC Software Triggering Supported
output [3:0]            cfg_dpc_rp_pio_log_size;              // DPC RP PIO Log Size
output                  cfg_dpc_dl_active_err_cor_support;    // DPC DL_Active ERR_COR Signaling Supported
output [1:0]            cfg_dpc_trig_en;                      // DPC Trigger Enable
output                  cfg_dpc_trig_status;                  // DPC Trigger Status
output                  dpc_triggered_detect;                 // 1 clock cycle pulse when DPC is triggered.
output                  dpc_int;                              // DPC Interrupt Status
output                  dpc_msi;                              // DPC Interrupt Status
output                  cfg_dpc_cpl_cntrl;                    // DPC Completion Control
output                  cfg_dpc_int_en;                       // DPC Interrupt Enable
output                  cfg_dpc_err_cor_en;                   // DPC ERR_COR Enable
output                  cfg_dpc_poison_tlp_egr_block_en;      // Poisoned TLP Egress Blocking Enable
output                  cfg_dpc_sw_trigger;                   // DPC Software Trigger
output                  cfg_dpc_dl_active_err_cor_en;         // DL_Active ERR_COR Enable
output     [7:0]       cfg_trg_evnt_cnt                  ;
output     [1:0]       cfg_evnt_to_cnt                   ;
output                 cfg_flit_err_cnt_en               ;
output                 cfg_interr_trg_evnt_cnt_ind       ;
output                 cfg_fber_measurement_en           ;
output                 cfg_clr_fber_cnt                  ;
output     [1:0]       cfg_gran_per_lane_err_rpt         ;
output                 cfg_rpt_longest_burst_vs_1st_burst;
output                 cfg_flit_log_trg_evnt_msi;
output                 cfg_pop_fifo_en;

output [9:0]                      cfg_flit_perf_interr_vec           ;    
output [2:0]                      cfg_ltssm_trck_reg_cnt             ;
output [2:0]                      cfg_flit_response_type             ;
output [1:0]                      cfg_flit_type_measured             ;
output                            cfg_track_mode                     ;
output [4:0]                      cfg_Ltssm_st_trans_trck            ;
output                            cfg_trg_evnt_interr                ;
output                            cfg_flit_latency_msi               ;
output                            cfg_sts_1_ltssm_trg_evnt_interr    ;
output                            cfg_sts_1_ltssm_latency_msi     ;

output                            cfg_flit_err_inj_en               ;
output                            cfg_inj_err_tx_flit_ind           ;
output                            cfg_inj_err_rx_flit_ind           ;
output  [12:0]                    cfg_flit_err_inj_en_data_rate     ;
output  [4:0]                     cfg_inj_err_num                   ;
output  [7:0]                     cfg_inj_err_spacing               ;
output  [2:0]                     cfg_flit_type_inj                 ;
output  [2:0]                     cfg_consec_err_inj                ;
output  [1:0]                     cfg_curr_inj_err_type             ;
output  [6:0]                     cfg_flit_err_off                  ;
output  [7:0]                     cfg_err_mag                       ;
output                            cfg_ordr_set_err_inj_en           ;
output                            cfg_inj_err_tx_ordr_set_ind       ;
output                            cfg_inj_err_rx_ordr_set_ind       ;
output  [7:3]                     cfg_ordr_set_inj_err_num          ;
output  [7:0]                     cfg_ordr_set_inj_err_spacing      ;
output                            cfg_inj_err_ts0_os                ;
output                            cfg_inj_err_ts1_os                ;
output                            cfg_inj_err_ts2_os                ;
output                            cfg_inj_err_skp_os                ;
output                            cfg_inj_err_eieos_os              ;
output                            cfg_inj_err_eios_os               ;
output                            cfg_inj_err_sds_os                ;
output                            cfg_inj_err_poll_st               ;
output                            cfg_inj_err_cfg_st                ;
output                            cfg_inj_err_l0_st                 ;
output                            cfg_inj_err_non_eq_recov_st       ;
output                            cfg_inj_err_recov_eq_ph_1_0       ;
output                            cfg_inj_err_recov_eq_ph_2         ;
output                            cfg_inj_err_recov_eq_ph_3         ;
output  [15:0]                    cfg_err_inj_bytes                 ;
output  [15:0]                    cfg_err_inj_lane_num              ;

// Output registers
wire    [3:0]   ecfg_write_pulse;
wire            ecfg_read_pulse;
reg     [ERR_REG_ID_WD-1:0]  err_reg_id;
reg     [31:0]  ecfg_reg_data;
reg             ecfg_reg_ack;
reg cxl_mbar0_reg_ack;
reg [3:0]cxl_mbar0_write_pulse;
reg [NCXL_MEMBAR0_CACHE_MEM-1:0] cxl_mbar0_cache_mem_reg_id;// Register select for RCRB MEMBAR0 CACHE MEM
reg [NCXL_MEMBAR0_ARB_MUX-1:0]   cxl_mbar0_arb_mux_reg_id;// Register select for RCRB MEMBAR0 ARB/MUX
wire ras_reg_sel;
reg  [NR_RAS_REGS-1: 0]  ras_reg_id;    
wire             spcie_reg_sel;
reg [NSPCIE-1:0] spcie_reg_id;
reg [NPL16G-1:0] pl16g_reg_id;
reg [NMARGIN-1:0] margin_reg_id;
reg [NPL32G-1:0] pl32g_reg_id;
reg [NPL64G-1:0] pl64g_reg_id;
reg [NL1SUB-1:0] l1sub_reg_id;
reg     [3:0]   dev3_reg_id;
wire            rasdes_reg_sel;
reg     [63:0]  rasdes_reg_id;
wire                    vsecdma_reg_sel;
reg     [5:0]           vsecdma_reg_id;

reg     [14:0]          cxl_reg_id;
reg     [7:0]           cxl_rcrb_reg_id;
reg     [9:0]           cxl_2_0_ext_reg_id;  
reg     [8:0]           cxl_reg_locator_reg_id;
reg     [3:0]           cxl_gpf_port_reg_id;        // Register select for CXL PORT GPF DVSEC
reg     [3:0]           cxl_gpf_device_reg_id;        // Register select for CXL DEVICE GPF DVSEC
reg     [2:0]   cfg_lpvc;
reg     [2:0]   cfg_vc_arb_sel;                     // Used to support different types of arbitration
logic   [7:0]   cfg_pwr_budget_data_sel_reg;
logic           cfg_pwr_budget_sel;
wire    [5:0]   cfg_rbar_bar_resizable;
wire    [63:0]  cfg_rbar_bar0_mask;
wire    [31:0]  cfg_rbar_bar1_mask;
wire    [63:0]  cfg_rbar_bar2_mask;
wire    [31:0]  cfg_rbar_bar3_mask;
wire    [63:0]  cfg_rbar_bar4_mask;
wire    [31:0]  cfg_rbar_bar5_mask;
wire             rbar_ctrl_update;
wire [(6*6)-1:0] cfg_rbar_size;
wire    [5:0]   cfg_vf_rbar_bar_resizable;
wire    [63:0]  cfg_vf_rbar_bar0_mask;
wire    [31:0]  cfg_vf_rbar_bar1_mask;
wire    [63:0]  cfg_vf_rbar_bar2_mask;
wire    [31:0]  cfg_vf_rbar_bar3_mask;
wire    [63:0]  cfg_vf_rbar_bar4_mask;
wire    [31:0]  cfg_vf_rbar_bar5_mask;
wire             vf_rbar_ctrl_update;
wire [(6*6)-1:0] cfg_vf_rbar_size;

// Internal signals
wire            pcie_sw_up;
wire            pcie_sw_down;
wire            switch_device;
wire            rc_device;
wire            end_device;
wire    [7:0]   ecfg_reg_00, ecfg_reg_01, ecfg_reg_02, ecfg_reg_03;
wire    [7:0]   ecfg_reg_04, ecfg_reg_05, ecfg_reg_06, ecfg_reg_07;
wire    [7:0]   ecfg_reg_08, ecfg_reg_09, ecfg_reg_10, ecfg_reg_11;
wire    [7:0]   ecfg_reg_12, ecfg_reg_13, ecfg_reg_14, ecfg_reg_15;
wire    [7:0]   ecfg_reg_16, ecfg_reg_17, ecfg_reg_18, ecfg_reg_19;
wire    [7:0]   ecfg_reg_20, ecfg_reg_21, ecfg_reg_22, ecfg_reg_23;
wire    [7:0]   ecfg_reg_24, ecfg_reg_25, ecfg_reg_26, ecfg_reg_27;
wire    [7:0]   ecfg_reg_28, ecfg_reg_29, ecfg_reg_30, ecfg_reg_31;
wire    [7:0]   ecfg_reg_32, ecfg_reg_33, ecfg_reg_34, ecfg_reg_35;
wire    [7:0]   ecfg_reg_36, ecfg_reg_37, ecfg_reg_38, ecfg_reg_39;
wire    [7:0]   ecfg_reg_43, ecfg_reg_42, ecfg_reg_41, ecfg_reg_40;
wire    [7:0]   ecfg_reg_47, ecfg_reg_46, ecfg_reg_45, ecfg_reg_44;
wire    [7:0]   ecfg_reg_51, ecfg_reg_50, ecfg_reg_49, ecfg_reg_48;
wire    [7:0]   ecfg_reg_55, ecfg_reg_54, ecfg_reg_53, ecfg_reg_52;
wire    [7:0]   ecfg_reg_59, ecfg_reg_58, ecfg_reg_57, ecfg_reg_56;
wire    [7:0]   ecfg_reg_63, ecfg_reg_62, ecfg_reg_61, ecfg_reg_60;
wire    [7:0]   ecfg_reg_67, ecfg_reg_66, ecfg_reg_65, ecfg_reg_64;
wire    [7:0]   ecfg_reg_71, ecfg_reg_70, ecfg_reg_69, ecfg_reg_68;
wire    [7:0]   ecfg_reg_75, ecfg_reg_74, ecfg_reg_73, ecfg_reg_72;
wire    [7:0]   ecfg_reg_79, ecfg_reg_78, ecfg_reg_77, ecfg_reg_76;
wire    [7:0]   ecfg_reg_83, ecfg_reg_82, ecfg_reg_81, ecfg_reg_80;
wire    [7:0]   ecfg_reg_87, ecfg_reg_86, ecfg_reg_85, ecfg_reg_84;
wire    [7:0]   ecfg_reg_91, ecfg_reg_90, ecfg_reg_89, ecfg_reg_88;
wire    [7:0]   ecfg_reg_95, ecfg_reg_94, ecfg_reg_93, ecfg_reg_92;
wire    [7:0]   ecfg_reg_99, ecfg_reg_98, ecfg_reg_97, ecfg_reg_96;
wire    [7:0]   ecfg_reg_103, ecfg_reg_102, ecfg_reg_101, ecfg_reg_100;
wire    [7:0]   ecfg_reg_107, ecfg_reg_106, ecfg_reg_105, ecfg_reg_104;
wire    [7:0]   ecfg_reg_111, ecfg_reg_110, ecfg_reg_109, ecfg_reg_108;


reg             ecfg_reg_sel_d;
reg             ecfg_reg_sel_dd;
reg     [3:0]   write_pulse;
reg             read_pulse;
reg     [27:0]  vc_reg_id;
wire    [7:0]   sn_reg_03, sn_reg_02, sn_reg_01, sn_reg_00;
wire    [7:0]   sn_reg_07, sn_reg_06, sn_reg_05, sn_reg_04;
wire    [7:0]   sn_reg_11, sn_reg_10, sn_reg_09, sn_reg_08;
reg     [2:0]   sn_reg_id;
reg     [31:0]  sn_reg_data;

reg     [3:0]   pb_reg_id;
reg     [31:0]  pb_reg_data;
wire    [31:0]  rbar_reg_data;
wire    [31:0]  vf_rbar_reg_data;
wire    [7:0]   pb_reg_03, pb_reg_02, pb_reg_01, pb_reg_00;
wire    [7:0]   pb_reg_07, pb_reg_06, pb_reg_05, pb_reg_04;
wire    [7:0]   pb_reg_11, pb_reg_10, pb_reg_09, pb_reg_08;
wire    [7:0]   pb_reg_15, pb_reg_14, pb_reg_13, pb_reg_12;
wire            ARI_EN;

wire    [31:0]  tph_reg_data;
wire    [1:0]   cfg_tph_req_en;
wire    [2:0]   cfg_pf_tph_st_mode;
reg     [2+`TPH_ST_TABLE_DEPTH:0] tph_reg_id;
wire    [31:0]           rtr_reg_data;
reg     [NRTR-1:0]       rtr_reg_id;




localparam NDLINK = 3; // There are three registers in the capability
wire [31:0]              dlink_reg_data;
reg [NDLINK-1:0]         dlink_reg_id;

reg     [NPTM-1:0]        ptm_reg_id;
reg     [NPTMVSEC-1:0]    ptm_vsec_reg_id;

wire    [31:0]            frsq_reg_data;
reg     [NFRSQ-1:0]       frsq_reg_id;

wire    [31:0] ats_reg_data;
wire    [4:0]  cfg_ats_stu;
wire           cfg_ats_cache_en;
reg     [1:0]  ats_reg_id;

wire    [31:0] prs_reg_data;
wire           cfg_prs_enable;                 // Enable Page Request cabability
wire           cfg_prs_reset;                  // Reset Page Request cabability
wire           cfg_prs_stopped;                // PRS Stopped
wire           cfg_prs_uprgi;                  // Detected a Unexpected PRG Index
wire           cfg_prs_response_failure;       // Detected a Response Failure
wire    [31:0] cfg_prs_outstanding_allocation; // PRS Outstanding Allocation
reg     [3:0]  prs_reg_id;

reg    [9:0]   acs_reg_id;
wire   [31:0]  acs_reg_data;
wire            cfg_acs_validation_cap;
wire            cfg_acs_at_blocking_cap;
wire            cfg_acs_up_forward_cap;
wire            cfg_acs_validation_en;
wire            cfg_acs_at_blocking_en;
wire            cfg_acs_p2p_req_redirect_en;
wire            cfg_acs_p2p_compl_redirect_en;
wire            cfg_acs_up_forward_en;
wire            cfg_acs_p2p_egress_ctrl_en;
wire            cfg_acs_p2p_direct_transl_en;
wire   [ACS_CTRL_VEC_WD-1:0]  cfg_acs_egress_ctrl_vec;

reg     [1:0]  ltr_reg_id;
wire    [31:0] ltr_reg_data;
wire    [31:0] cfg_ltr_max_latency;

wire     [`CX_PASID_CONTROL_WD-1:0] cfg_pf_pasid_control;           // PF PASID control signal bus
wire     [31:0]                     pasid_reg_data;                 // PASID Register Read Data
reg      [NPASID-1:0]               pasid_reg_id;                   // PASID Register ID


wire   [4:0]            cfg_dpc_int_msg_num;                  // DPC Interrupt Message Number
wire                    cfg_dpc_rp_ext_dpc;                   // DPC Root Port Extensions for DPC
wire                    cfg_dpc_poison_tlp_egr_blk_support;   // DPC Poisoned TLP Egress Blocking Supported
wire                    cfg_dpc_sw_trig_support;              // DPC Software Triggering Supported
wire   [3:0]            cfg_dpc_rp_pio_log_size;              // DPC RP PIO Log Size
wire                    cfg_dpc_dl_active_err_cor_support;    // DPC DL_Active ERR_COR Signaling Supported
wire   [1:0]            cfg_dpc_trig_en;                      // DPC Trigger Enable
wire                    cfg_dpc_trig_status;                  // DPC Trigger Status
wire                    dpc_int;                              // DPC Interrupt Status
wire                    dpc_msi;                              // DPC Interrupt Status
wire                    cfg_dpc_cpl_cntrl;                    // DPC Completion Control
wire                    cfg_dpc_int_en;                       // DPC Interrupt Enable
wire                    cfg_dpc_err_cor_en;                   // DPC ERR_COR Enable
wire                    cfg_dpc_poison_tlp_egr_block_en;      // Poisoned TLP Egress Blocking Enable
wire                    cfg_dpc_sw_trigger;                   // DPC Software Trigger
wire                    cfg_dpc_dl_active_err_cor_en;         // DL_Active ERR_COR Enable
wire   [31:0]           dpc_reg_data;                         // DPC Register Read Data
reg    [NDPC-1:0]       dpc_reg_id;                           // DPC Register ID






assign ras_reg_sel  = (cfg_ras_reg_pf0_only & (FUNC_NUM!=0)) ? 1'b0 : |ras_reg_id;
reg   [FLITLOGGING-1:0]  flit_logging_reg_id;               // Flit Logging Register ID
wire  [31:0]             flit_logging_reg_data;             // Flit Logging Register Read Data

reg [FLIT_PERF_MEASUREMENT-1:0]   flit_perf_msur_reg_id;
wire  [31:0]                      flit_perf_msur_reg_data;

reg [FLIT_ERR_INJ-1:0]            flit_err_inj_reg_id;
wire  [31:0]                      flit_err_inj_reg_data;

localparam RID = (NL/2 + 3);

localparam CX_ACS_EGRESS_CTRL_SIZE = `CX_ACS_EGRESS_CTRL_SIZE;

assign rasdes_reg_sel  = (cfg_rasdes_reg_pf0_only & (FUNC_NUM!=0)) ? 1'b0 : |rasdes_reg_id;


assign vsecdma_reg_sel          = |vsecdma_reg_id;
assign ecfg_write_pulse = write_pulse;
assign ecfg_read_pulse  = read_pulse;

assign end_device       = (device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY);
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_up       = (device_type == `PCIE_SW_UP);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);
assign switch_device    = pcie_sw_up | pcie_sw_down;

assign ARI_EN           = ARI_EN_VAL; // STAR 9000470917

// ECFG register enable
wire ecfg_reg_id_en;
assign ecfg_reg_id_en = ecfg_reg_sel | ecfg_reg_sel_d;
wire cxl_mbar0_reg_id_en;
reg cxl_mbar0_reg_sel_d;
assign cxl_mbar0_reg_id_en = cxl_mbar0_reg_sel | cxl_mbar0_reg_sel_d;
wire cache_mem;
wire arb_mux;
assign cache_mem = (lbc_cdm_addr[15:12] == 4'b0001);
assign arb_mux = (lbc_cdm_addr[15:12] == 4'b1110);

// =============================================================================
// PCIE Extended Configuration select
// -- The Extended Configuration Registers are located in device configuration sel
// at offsets 256 or greater (up to 4096).
// =============================================================================
generate
if(FUNC_NUM == 0 & VC_EN) begin : gen_vc_reg_id
  always @(posedge core_clk or negedge non_sticky_rst_n)
  begin
    if(!non_sticky_rst_n) begin
        vc_reg_id       <= #TP 0;
    end else if ((|RCRB) ^ cxl_rcrb_enable) begin
        vc_reg_id       <= #TP 0;
    end else begin
        vc_reg_id[0]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : vc_reg_id[0];
        vc_reg_id[1]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : vc_reg_id[1];
        vc_reg_id[2]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : vc_reg_id[2];
        vc_reg_id[3]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : vc_reg_id[3];
            // VC0
            vc_reg_id[4]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : vc_reg_id[4];
            vc_reg_id[5]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : vc_reg_id[5];
            vc_reg_id[6]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : vc_reg_id[6];
            // VC1

            if (NVC > 1) begin
                vc_reg_id[7]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + 4'hC) >> 2)) & ecfg_reg_sel) : vc_reg_id[7];
                vc_reg_id[8]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + 4'hC) >> 2)) & ecfg_reg_sel) : vc_reg_id[8];
                vc_reg_id[9]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + 4'hC) >> 2)) & ecfg_reg_sel) : vc_reg_id[9];
            end
            else
                vc_reg_id[9:7]  <= #TP 0;
            // VC2
            if (NVC > 2) begin
                vc_reg_id[10]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (2 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[10];
                vc_reg_id[11]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (2 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[11];
                vc_reg_id[12]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (2 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[12];
            end
            else
                vc_reg_id[12:10]<= #TP 0;
            // VC3
            if (NVC > 3) begin
                vc_reg_id[13]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (3 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[13];
                vc_reg_id[14]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (3 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[14];
                vc_reg_id[15]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (3 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[15];
            end
            else
                vc_reg_id[15:13]<= #TP 0;
            // VC4
            if (NVC > 4) begin
                vc_reg_id[16]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (4 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[16];
                vc_reg_id[17]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (4 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[17];
                vc_reg_id[18]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (4 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[18];
            end
            else
                vc_reg_id[18:16]<= #TP 0;
            // VC3
            if (NVC > 5) begin
                vc_reg_id[19]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (5 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[19];
                vc_reg_id[20]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (5 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[20];
                vc_reg_id[21]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (5 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[21];
            end
            else
                vc_reg_id[21:19]<= #TP 0;
            // VC3
            if (NVC > 6) begin
                vc_reg_id[22]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (6 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[22];
                vc_reg_id[23]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (6 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[23];
                vc_reg_id[24]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (6 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[24];
            end
            else
                vc_reg_id[24:22]<= #TP 0;
            // VC3
            if (NVC > 7) begin
                vc_reg_id[25]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (7 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[25];
                vc_reg_id[26]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (7 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[26];
                vc_reg_id[27]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (7 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[27];
            end
            else
                vc_reg_id[27:25]<= #TP 0;


      end
    end
  end // if (FUNC_NUM==0 && VC_EN)

  else if (VC_EN) begin : gen_vc_reg_id         // all other functions

    always @(posedge core_clk or negedge non_sticky_rst_n)
    begin
      if(!non_sticky_rst_n) begin
        vc_reg_id       <= #TP 0;
      end else if ((|RCRB) ^ cxl_rcrb_enable) begin
        vc_reg_id       <= #TP 0;
      end else begin
          vc_reg_id[0]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : vc_reg_id[0];
        vc_reg_id[27:1] <= #TP 0;
      end
    end
  end // if(VC_EN)

  else begin : gen_vc_reg_id // not VC_EN, FUNC_NUM !=0
    always @(posedge core_clk or negedge non_sticky_rst_n)
    begin
      if(!non_sticky_rst_n) begin
        vc_reg_id       <= #TP 0;
      end else begin
        vc_reg_id   <= #TP 0;
      end
    end
  end // gen_vc_reg_id

endgenerate


always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        err_reg_id      <= #TP 0;
        sn_reg_id       <= #TP 0;
        pb_reg_id       <= #TP 0;
        ras_reg_id      <= #TP 0;
        spcie_reg_id    <= #TP 0;
        pl16g_reg_id    <= #TP 0;
        pl32g_reg_id    <= #TP 0;
        pl64g_reg_id    <= #TP 0;
        margin_reg_id   <= #TP 0;
        l1sub_reg_id    <= #TP 0;
        dev3_reg_id    <= #TP 0;
       ats_reg_id       <= #TP 0;
       acs_reg_id       <= #TP 0;
       prs_reg_id       <= #TP 0;
       ltr_reg_id       <= #TP 0;
       pasid_reg_id     <= #TP 0;
       rasdes_reg_id     <= #TP 0;
       vsecdma_reg_id    <= #TP 0;
       cxl_reg_id                   <= #TP 0;
       cxl_rcrb_reg_id              <= #TP 0;
       cxl_mbar0_cache_mem_reg_id   <= #TP 0;
       cxl_mbar0_arb_mux_reg_id     <= #TP 0;
       cxl_2_0_ext_reg_id           <= #TP 0;  
       cxl_reg_locator_reg_id       <= #TP 0;
       cxl_gpf_port_reg_id          <= #TP 0;
       cxl_gpf_device_reg_id        <= #TP 0;
       flit_logging_reg_id          <= #TP {FLITLOGGING{1'b0}};  
       flit_perf_msur_reg_id        <= #TP 0;
       flit_err_inj_reg_id          <= #TP 0;
    end
    else begin
        if (AER_EN) begin
            err_reg_id[0]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : err_reg_id[0];
            err_reg_id[1]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : err_reg_id[1];
            err_reg_id[2]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : err_reg_id[2];
            err_reg_id[3]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h00c) >> 2)) & ecfg_reg_sel) : err_reg_id[3];
            err_reg_id[4]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : err_reg_id[4];
            err_reg_id[5]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : err_reg_id[5];
            err_reg_id[6]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : err_reg_id[6];
            err_reg_id[7]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h01C) >> 2)) & ecfg_reg_sel) : err_reg_id[7];
            err_reg_id[8]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h020) >> 2)) & ecfg_reg_sel) : err_reg_id[8];
            err_reg_id[9]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h024) >> 2)) & ecfg_reg_sel) : err_reg_id[9];
            err_reg_id[10]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h028) >> 2)) & ecfg_reg_sel) : err_reg_id[10];
            err_reg_id[14]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h038) >> 2)) & ecfg_reg_sel) : err_reg_id[14];
            err_reg_id[15]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h03C) >> 2)) & ecfg_reg_sel) : err_reg_id[15];
            err_reg_id[16]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h040) >> 2)) & ecfg_reg_sel) : err_reg_id[16];
            err_reg_id[17]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h044) >> 2)) & ecfg_reg_sel) : err_reg_id[17];
            err_reg_id[18]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h048) >> 2)) & ecfg_reg_sel ) : err_reg_id[18];

            // The next 3 is for RC only
            if (rc_device) begin
                err_reg_id[11]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h02C) >> 2)) & ecfg_reg_sel ) : err_reg_id[11];
                err_reg_id[12]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h030) >> 2)) & ecfg_reg_sel ) : err_reg_id[12];
                err_reg_id[13]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h034) >> 2)) & ecfg_reg_sel ) : err_reg_id[13];
            end
            else begin
                err_reg_id[11]  <= #TP 0;
                err_reg_id[12]  <= #TP 0;
                err_reg_id[13]  <= #TP 0;
            end

        end
        else begin
            err_reg_id[ERR_REG_ID_WD-1:0]    <= #TP 0;
        end
        if (SN_EN) begin
            sn_reg_id[0]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SN_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : sn_reg_id[0];
            sn_reg_id[1]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SN_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : sn_reg_id[1];
            sn_reg_id[2]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SN_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : sn_reg_id[2];
        end
        else
            sn_reg_id[2:0]  <= #TP 0;
        if (PB_EN) begin
            pb_reg_id[0]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PB_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : pb_reg_id[0];
            pb_reg_id[1]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PB_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : pb_reg_id[1];
            pb_reg_id[2]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PB_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : pb_reg_id[2];
            pb_reg_id[3]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PB_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : pb_reg_id[3];
        end
        else
            pb_reg_id[3:0]  <= #TP 0;


      if (|RCRB) begin
       ras_reg_id        <= #TP 0;
      end else begin
       ras_reg_id[0]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : ras_reg_id[0];
       ras_reg_id[1]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : ras_reg_id[1];
       ras_reg_id[2]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : ras_reg_id[2];
       ras_reg_id[3]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : ras_reg_id[3];
       ras_reg_id[4]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : ras_reg_id[4];
       ras_reg_id[5]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : ras_reg_id[5];
       ras_reg_id[6]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : ras_reg_id[6];
       ras_reg_id[7]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h01C) >> 2)) & ecfg_reg_sel) : ras_reg_id[7];
       ras_reg_id[8]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h020) >> 2)) & ecfg_reg_sel) : ras_reg_id[8];
       ras_reg_id[9]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h024) >> 2)) & ecfg_reg_sel) : ras_reg_id[9];
       ras_reg_id[10] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h028) >> 2)) & ecfg_reg_sel) : ras_reg_id[10];
       ras_reg_id[11] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h02C) >> 2)) & ecfg_reg_sel) : ras_reg_id[11];
       ras_reg_id[12] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h030) >> 2)) & ecfg_reg_sel) : ras_reg_id[12];
       ras_reg_id[13] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h034) >> 2)) & ecfg_reg_sel) : ras_reg_id[13];
       ras_reg_id[14] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h038) >> 2)) & ecfg_reg_sel) : ras_reg_id[14];
       ras_reg_id[15] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h03C) >> 2)) & ecfg_reg_sel) : ras_reg_id[15];
       ras_reg_id[16] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h040) >> 2)) & ecfg_reg_sel) : ras_reg_id[16];
       ras_reg_id[17] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h044) >> 2)) & ecfg_reg_sel) : ras_reg_id[17];
       ras_reg_id[18] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h048) >> 2)) & ecfg_reg_sel) : ras_reg_id[18];
       ras_reg_id[19] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h04C) >> 2)) & ecfg_reg_sel) : ras_reg_id[19];
       ras_reg_id[20] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h050) >> 2)) & ecfg_reg_sel) : ras_reg_id[20];
       ras_reg_id[21] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h054) >> 2)) & ecfg_reg_sel) : ras_reg_id[21];
       ras_reg_id[22] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h058) >> 2)) & ecfg_reg_sel) : ras_reg_id[22];
       ras_reg_id[23] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h05C) >> 2)) & ecfg_reg_sel) : ras_reg_id[23];
       ras_reg_id[24] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECRAS_PTR + 12'h060) >> 2)) & ecfg_reg_sel) : ras_reg_id[24];
      end

        spcie_reg_id        <= #TP spcie_reg_id; // to avoid a latch on unassigned bits
        spcie_reg_id[0]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SPCIE_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : spcie_reg_id[0];
        spcie_reg_id[1]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SPCIE_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : spcie_reg_id[1];
        spcie_reg_id[2]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SPCIE_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : spcie_reg_id[2];
        spcie_reg_id[3]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SPCIE_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : spcie_reg_id[3];
        spcie_reg_id[4]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SPCIE_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : spcie_reg_id[4];
        spcie_reg_id[5]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SPCIE_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : spcie_reg_id[5];
        spcie_reg_id[6]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SPCIE_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : spcie_reg_id[6];

        pl16g_reg_id        <= #TP pl16g_reg_id; // to avoid a latch on unassigned bits
        pl16g_reg_id[0]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL16G_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : pl16g_reg_id[0];
        pl16g_reg_id[1]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL16G_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : pl16g_reg_id[1];
        pl16g_reg_id[2]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL16G_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : pl16g_reg_id[2];
        pl16g_reg_id[3]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL16G_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : pl16g_reg_id[3];
        pl16g_reg_id[4]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL16G_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : pl16g_reg_id[4];
        pl16g_reg_id[5]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL16G_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : pl16g_reg_id[5];
        pl16g_reg_id[6]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL16G_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : pl16g_reg_id[6];
        pl16g_reg_id[7]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL16G_PTR + 12'h01C) >> 2)) & ecfg_reg_sel) : pl16g_reg_id[7];
        pl16g_reg_id[8]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL16G_PTR + 12'h020) >> 2)) & ecfg_reg_sel) : pl16g_reg_id[8];
        pl16g_reg_id[9]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL16G_PTR + 12'h024) >> 2)) & ecfg_reg_sel) : pl16g_reg_id[9];

        margin_reg_id       <= #TP margin_reg_id; // to avoid a latch on unassigned bits
        margin_reg_id[0]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `MARGIN_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : margin_reg_id[0];
        margin_reg_id[1]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `MARGIN_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : margin_reg_id[1];
        margin_reg_id[2]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `MARGIN_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : margin_reg_id[2];
        margin_reg_id[3]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `MARGIN_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : margin_reg_id[3];
        margin_reg_id[4]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `MARGIN_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : margin_reg_id[4];
        margin_reg_id[5]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `MARGIN_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : margin_reg_id[5];
        margin_reg_id[6]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `MARGIN_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : margin_reg_id[6];
        margin_reg_id[7]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `MARGIN_PTR + 12'h01C) >> 2)) & ecfg_reg_sel) : margin_reg_id[7];
        margin_reg_id[8]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `MARGIN_PTR + 12'h020) >> 2)) & ecfg_reg_sel) : margin_reg_id[8];
        margin_reg_id[9]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `MARGIN_PTR + 12'h024) >> 2)) & ecfg_reg_sel) : margin_reg_id[9];

        pl32g_reg_id        <= #TP pl32g_reg_id; // to avoid a latch on unassigned bits
        pl32g_reg_id[0]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL32G_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : pl32g_reg_id[0];
        pl32g_reg_id[1]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL32G_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : pl32g_reg_id[1];
        pl32g_reg_id[2]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL32G_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : pl32g_reg_id[2];
        pl32g_reg_id[3]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL32G_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : pl32g_reg_id[3];
        pl32g_reg_id[4]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL32G_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : pl32g_reg_id[4];
        pl32g_reg_id[5]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL32G_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : pl32g_reg_id[5];
        pl32g_reg_id[6]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL32G_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : pl32g_reg_id[6];
        pl32g_reg_id[7]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL32G_PTR + 12'h01C) >> 2)) & ecfg_reg_sel) : pl32g_reg_id[7];
        pl32g_reg_id[8]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL32G_PTR + 12'h020) >> 2)) & ecfg_reg_sel) : pl32g_reg_id[8];
        pl32g_reg_id[9]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL32G_PTR + 12'h024) >> 2)) & ecfg_reg_sel) : pl32g_reg_id[9];
        pl64g_reg_id        <= #TP pl64g_reg_id; // to avoid a latch on unassigned bits
        pl64g_reg_id[0]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL64G_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : pl64g_reg_id[0];
        pl64g_reg_id[1]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL64G_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : pl64g_reg_id[1];
        pl64g_reg_id[2]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL64G_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : pl64g_reg_id[2];
        pl64g_reg_id[3]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL64G_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : pl64g_reg_id[3];
        pl64g_reg_id[4]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL64G_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : pl64g_reg_id[4];
        pl64g_reg_id[5]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PL64G_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : pl64g_reg_id[5];

        l1sub_reg_id[0]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `L1SUB_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : l1sub_reg_id[0];
        l1sub_reg_id[1]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `L1SUB_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : l1sub_reg_id[1];
        l1sub_reg_id[2]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `L1SUB_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : l1sub_reg_id[2];
        l1sub_reg_id[3]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `L1SUB_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : l1sub_reg_id[3];


        dev3_reg_id[0]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`DEV3_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : dev3_reg_id[0];
        dev3_reg_id[1]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`DEV3_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : dev3_reg_id[1];
        dev3_reg_id[2]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`DEV3_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : dev3_reg_id[2];
        dev3_reg_id[3]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`DEV3_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : dev3_reg_id[3];

        ats_reg_id[0]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `ATS_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : ats_reg_id[0];
        ats_reg_id[1]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `ATS_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : ats_reg_id[1];


        acs_reg_id[0]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `ACS_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : acs_reg_id[0];
        acs_reg_id[1]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`ACS_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : acs_reg_id[1];
        acs_reg_id[2]       <= #TP ecfg_reg_id_en ? (ACS_CTRL_VEC_WD > 0   && (lbc_cdm_addr[11:2] == (( `ACS_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : acs_reg_id[2];
        acs_reg_id[3]       <= #TP ecfg_reg_id_en ? (ACS_CTRL_VEC_WD > 32  && (lbc_cdm_addr[11:2] == (( `ACS_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : acs_reg_id[3];
        acs_reg_id[4]       <= #TP ecfg_reg_id_en ? (ACS_CTRL_VEC_WD > 64  && (lbc_cdm_addr[11:2] == ((`ACS_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : acs_reg_id[4];
        acs_reg_id[5]       <= #TP ecfg_reg_id_en ? (ACS_CTRL_VEC_WD > 96  && (lbc_cdm_addr[11:2] == ((`ACS_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : acs_reg_id[5];
        acs_reg_id[6]       <= #TP ecfg_reg_id_en ? (ACS_CTRL_VEC_WD > 128 && (lbc_cdm_addr[11:2] == ((`ACS_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : acs_reg_id[6];
        acs_reg_id[7]       <= #TP ecfg_reg_id_en ? (ACS_CTRL_VEC_WD > 160 && (lbc_cdm_addr[11:2] == ((`ACS_PTR + 12'h01C) >> 2)) & ecfg_reg_sel) : acs_reg_id[7];
        acs_reg_id[8]       <= #TP ecfg_reg_id_en ? (ACS_CTRL_VEC_WD > 192 && (lbc_cdm_addr[11:2] == ((`ACS_PTR + 12'h020) >> 2)) & ecfg_reg_sel) : acs_reg_id[8];
        acs_reg_id[9]       <= #TP ecfg_reg_id_en ? (ACS_CTRL_VEC_WD > 224 && (lbc_cdm_addr[11:2] == ((`ACS_PTR + 12'h024) >> 2)) & ecfg_reg_sel) : acs_reg_id[9];

        prs_reg_id[0]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PRS_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : prs_reg_id[0];
        prs_reg_id[1]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PRS_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : prs_reg_id[1];
        prs_reg_id[2]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PRS_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : prs_reg_id[2];
        prs_reg_id[3]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PRS_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : prs_reg_id[3];

        ltr_reg_id[0]       <= #TP (ecfg_reg_id_en && upstream_port) ? ((lbc_cdm_addr[11:2] == (( `LTR_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : ltr_reg_id[0];
        ltr_reg_id[1]       <= #TP (ecfg_reg_id_en && upstream_port) ? ((lbc_cdm_addr[11:2] == (( `LTR_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : ltr_reg_id[1];

        pasid_reg_id[0]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PASID_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : pasid_reg_id[0];
        pasid_reg_id[1]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PASID_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : pasid_reg_id[1];

      if (|RCRB) begin
       rasdes_reg_id        <= #TP 0;
      end else begin
       rasdes_reg_id[0]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[0];
       rasdes_reg_id[1]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[1];
       rasdes_reg_id[2]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[2];
       rasdes_reg_id[3]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[3];
       rasdes_reg_id[4]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[4];
       rasdes_reg_id[5]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[5];
       rasdes_reg_id[6]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[6];
       rasdes_reg_id[7]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h01C) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[7];
       rasdes_reg_id[8]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h020) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[8];
       rasdes_reg_id[9]     <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h024) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[9];
       rasdes_reg_id[10]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h028) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[10];
       rasdes_reg_id[11]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h02C) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[11];
       rasdes_reg_id[12]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h030) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[12];
       rasdes_reg_id[13]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h034) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[13];
       rasdes_reg_id[14]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h038) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[14];
       rasdes_reg_id[15]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h03C) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[15];
       rasdes_reg_id[16]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h040) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[16];
       rasdes_reg_id[17]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h044) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[17];
       rasdes_reg_id[18]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h048) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[18];
       rasdes_reg_id[19]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h04C) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[19];
       rasdes_reg_id[20]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h050) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[20];
       rasdes_reg_id[21]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h054) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[21];
       rasdes_reg_id[22]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h058) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[22];
       rasdes_reg_id[23]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h05C) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[23];
       rasdes_reg_id[24]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h060) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[24];
       rasdes_reg_id[25]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h064) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[25];
       rasdes_reg_id[26]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h068) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[26];
       rasdes_reg_id[27]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h06C) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[27];
       rasdes_reg_id[28]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h070) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[28];
       rasdes_reg_id[29]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h074) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[29];
       rasdes_reg_id[30]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h078) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[30];
       rasdes_reg_id[31]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h07C) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[31];
       rasdes_reg_id[32]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h080) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[32];
       rasdes_reg_id[33]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h084) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[33];
       rasdes_reg_id[34]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h088) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[34];
       rasdes_reg_id[35]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h08C) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[35];
       rasdes_reg_id[36]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h090) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[36];
       rasdes_reg_id[37]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h094) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[37];
       rasdes_reg_id[38]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h098) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[38];
       rasdes_reg_id[39]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h09C) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[39];
       rasdes_reg_id[40]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0A0) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[40];
       rasdes_reg_id[41]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0A4) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[41];
       rasdes_reg_id[42]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0A8) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[42];
       rasdes_reg_id[43]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0AC) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[43];
       rasdes_reg_id[44]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0B0) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[44];
       rasdes_reg_id[45]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0B4) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[45];
       rasdes_reg_id[46]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0B8) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[46];
       rasdes_reg_id[47]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0BC) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[47];
       rasdes_reg_id[48]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0C0) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[48];
       rasdes_reg_id[49]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0C4) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[49];
       rasdes_reg_id[50]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0C8) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[50];
       rasdes_reg_id[51]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0CC) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[51];
       rasdes_reg_id[52]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0D0) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[52];
       rasdes_reg_id[53]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0D4) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[53];
       rasdes_reg_id[54]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0D8) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[54];
       rasdes_reg_id[55]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0DC) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[55];
       rasdes_reg_id[56]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0E0) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[56];
       rasdes_reg_id[57]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0E4) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[57];
       rasdes_reg_id[58]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0E8) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[58];
       rasdes_reg_id[59]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0EC) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[59];
       rasdes_reg_id[60]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0F0) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[60];
       rasdes_reg_id[61]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0F4) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[61];
       rasdes_reg_id[62]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0F8) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[62];
       rasdes_reg_id[63]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RAS_DES_PTR + 12'h0FC) >> 2)) & ecfg_reg_sel) : rasdes_reg_id[63];
      end
       vsecdma_reg_id[0]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECDMA_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : vsecdma_reg_id[0];
       vsecdma_reg_id[1]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECDMA_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : vsecdma_reg_id[1];
       vsecdma_reg_id[2]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECDMA_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : vsecdma_reg_id[2];
       vsecdma_reg_id[3]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECDMA_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : vsecdma_reg_id[3];
       vsecdma_reg_id[4]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECDMA_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : vsecdma_reg_id[4];
       vsecdma_reg_id[5]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VSECDMA_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : vsecdma_reg_id[5];
       if (~(|RCRB)) begin
          cxl_reg_id[0]     <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h000) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[1]     <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h004) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[2]     <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h008) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[3]     <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h00C) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[4]     <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h010) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[5]     <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h014) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[6]     <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h018) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[7]     <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h01C) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[8]     <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h020) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[9]     <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h024) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[10]    <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h028) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[11]    <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h02C) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[12]    <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h030) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[13]    <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h034) >> 2)) & ecfg_reg_sel;
          cxl_reg_id[14]    <= #TP (lbc_cdm_addr[11:2] == ((`DEVICE_PTR + 12'h038) >> 2)) & ecfg_reg_sel;
        cxl_2_0_ext_reg_id[0]        <= #TP (lbc_cdm_addr[11:2] == ((`CXL_2_0_EXT_PTR + 12'h000) >> 2)) & ecfg_reg_sel;
        cxl_2_0_ext_reg_id[1]        <= #TP (lbc_cdm_addr[11:2] == ((`CXL_2_0_EXT_PTR + 12'h004) >> 2)) & ecfg_reg_sel;
        cxl_2_0_ext_reg_id[2]        <= #TP (lbc_cdm_addr[11:2] == ((`CXL_2_0_EXT_PTR + 12'h008) >> 2)) & ecfg_reg_sel;
        cxl_2_0_ext_reg_id[3]        <= #TP (lbc_cdm_addr[11:2] == ((`CXL_2_0_EXT_PTR + 12'h00C) >> 2)) & ecfg_reg_sel;
        cxl_2_0_ext_reg_id[4]        <= #TP (lbc_cdm_addr[11:2] == ((`CXL_2_0_EXT_PTR + 12'h010) >> 2)) & ecfg_reg_sel;
        cxl_2_0_ext_reg_id[5]        <= #TP (lbc_cdm_addr[11:2] == ((`CXL_2_0_EXT_PTR + 12'h014) >> 2)) & ecfg_reg_sel;
        cxl_2_0_ext_reg_id[6]        <= #TP (lbc_cdm_addr[11:2] == ((`CXL_2_0_EXT_PTR + 12'h018) >> 2)) & ecfg_reg_sel;
        cxl_2_0_ext_reg_id[7]        <= #TP (lbc_cdm_addr[11:2] == ((`CXL_2_0_EXT_PTR + 12'h01C) >> 2)) & ecfg_reg_sel;
        cxl_2_0_ext_reg_id[8]        <= #TP (lbc_cdm_addr[11:2] == ((`CXL_2_0_EXT_PTR + 12'h020) >> 2)) & ecfg_reg_sel;
        cxl_2_0_ext_reg_id[9]        <= #TP (lbc_cdm_addr[11:2] == ((`CXL_2_0_EXT_PTR + 12'h024) >> 2)) & ecfg_reg_sel;  
        cxl_reg_locator_reg_id[0]    <= #TP (lbc_cdm_addr[11:2] == ((`CXL_REG_LOCATOR_PTR + 12'h000) >> 2)) & ecfg_reg_sel;
        cxl_reg_locator_reg_id[1]    <= #TP (lbc_cdm_addr[11:2] == ((`CXL_REG_LOCATOR_PTR + 12'h004) >> 2)) & ecfg_reg_sel;
        cxl_reg_locator_reg_id[2]    <= #TP (lbc_cdm_addr[11:2] == ((`CXL_REG_LOCATOR_PTR + 12'h008) >> 2)) & ecfg_reg_sel;
        cxl_reg_locator_reg_id[3]    <= #TP (lbc_cdm_addr[11:2] == ((`CXL_REG_LOCATOR_PTR + 12'h00C) >> 2)) & ecfg_reg_sel;
        cxl_reg_locator_reg_id[4]    <= #TP (lbc_cdm_addr[11:2] == ((`CXL_REG_LOCATOR_PTR + 12'h010) >> 2)) & ecfg_reg_sel;
        cxl_reg_locator_reg_id[5]    <= #TP (lbc_cdm_addr[11:2] == ((`CXL_REG_LOCATOR_PTR + 12'h014) >> 2)) & ecfg_reg_sel;
        cxl_reg_locator_reg_id[6]    <= #TP (lbc_cdm_addr[11:2] == ((`CXL_REG_LOCATOR_PTR + 12'h018) >> 2)) & ecfg_reg_sel;
        cxl_reg_locator_reg_id[7]    <= #TP (lbc_cdm_addr[11:2] == ((`CXL_REG_LOCATOR_PTR + 12'h01C) >> 2)) & ecfg_reg_sel;
        cxl_reg_locator_reg_id[8]    <= #TP (lbc_cdm_addr[11:2] == ((`CXL_REG_LOCATOR_PTR + 12'h020) >> 2)) & ecfg_reg_sel;
        cxl_gpf_port_reg_id[0]       <= #TP (lbc_cdm_addr[11:2] == ((`CXL_GPF_PORT_PTR + 12'h000) >> 2)) & ecfg_reg_sel;
        cxl_gpf_port_reg_id[1]       <= #TP (lbc_cdm_addr[11:2] == ((`CXL_GPF_PORT_PTR + 12'h004) >> 2)) & ecfg_reg_sel;
        cxl_gpf_port_reg_id[2]       <= #TP (lbc_cdm_addr[11:2] == ((`CXL_GPF_PORT_PTR + 12'h008) >> 2)) & ecfg_reg_sel;
        cxl_gpf_port_reg_id[3]       <= #TP (lbc_cdm_addr[11:2] == ((`CXL_GPF_PORT_PTR + 12'h00C) >> 2)) & ecfg_reg_sel; 
        cxl_gpf_device_reg_id[0]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_GPF_DEVICE_PTR + 12'h000) >> 2)) & ecfg_reg_sel;
        cxl_gpf_device_reg_id[1]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_GPF_DEVICE_PTR + 12'h004) >> 2)) & ecfg_reg_sel;
        cxl_gpf_device_reg_id[2]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_GPF_DEVICE_PTR + 12'h008) >> 2)) & ecfg_reg_sel;
        cxl_gpf_device_reg_id[3]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_GPF_DEVICE_PTR + 12'h00C) >> 2)) & ecfg_reg_sel; 
       end else begin
          cxl_reg_id              <= #TP 0;
          cxl_2_0_ext_reg_id      <= #TP 0;
          cxl_reg_locator_reg_id  <= #TP 0;
          cxl_gpf_port_reg_id     <= #TP 0;
          cxl_gpf_device_reg_id   <= #TP 0;
       end
          cxl_rcrb_reg_id[0]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_PORT_PTR + 12'h000) >> 2)) & ecfg_reg_sel;
          cxl_rcrb_reg_id[1]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_PORT_PTR + 12'h004) >> 2)) & ecfg_reg_sel;
          cxl_rcrb_reg_id[2]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_PORT_PTR + 12'h008) >> 2)) & ecfg_reg_sel;
          cxl_rcrb_reg_id[3]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_PORT_PTR + 12'h00C) >> 2)) & ecfg_reg_sel;
          cxl_rcrb_reg_id[4]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_PORT_PTR + 12'h010) >> 2)) & ecfg_reg_sel;
          cxl_rcrb_reg_id[5]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_PORT_PTR + 12'h014) >> 2)) & ecfg_reg_sel;
          cxl_rcrb_reg_id[6]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_PORT_PTR + 12'h018) >> 2)) & ecfg_reg_sel;
          cxl_rcrb_reg_id[7]     <= #TP (lbc_cdm_addr[11:2] == ((`CXL_PORT_PTR + 12'h01C) >> 2)) & ecfg_reg_sel;
          cxl_mbar0_cache_mem_reg_id[0] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_PTR + 12'h000) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[1] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_PTR + 12'h004) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[2] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_PTR + 12'h008) >> 2)) & cxl_mbar0_reg_sel & cache_mem & (~upstream_port) & (~cxl2p0_enabled);
          cxl_mbar0_cache_mem_reg_id[3] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_PTR + 12'h00C) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[4] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h000) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[5] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h004) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[6] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h008) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[7] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h00C) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[8] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h010) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[9] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h014) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[10] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h018) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[11] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h01C) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[12] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h020) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[13] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h024) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[14] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h028) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[15] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h02C) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[16] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h030) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[17] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h034) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[18] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h038) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[19] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h03C) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[20] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h040) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[21] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h044) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[22] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h048) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[23] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h04C) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[24] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h050) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[25] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 12'h054) >> 2)) & cxl_mbar0_reg_sel & cache_mem;
          cxl_mbar0_cache_mem_reg_id[26] <= #TP (lbc_cdm_addr[11:2] == ((`CXL_RCRB_MEMBAR0_SEC_CAP_PTR + 12'h000) >> 2)) & cxl_mbar0_reg_sel & cache_mem & (~upstream_port) & (~cxl2p0_enabled);
          cxl_mbar0_arb_mux_reg_id[0] <= #TP (lbc_cdm_addr[11:2] == (12'h180 >> 2)) & cxl_mbar0_reg_sel & arb_mux;
          cxl_mbar0_arb_mux_reg_id[1] <= #TP (lbc_cdm_addr[11:2] == (12'h1C0 >> 2)) & cxl_mbar0_reg_sel & arb_mux;
          cxl_mbar0_arb_mux_reg_id[2] <= #TP (lbc_cdm_addr[11:2] == (12'h000 >> 2)) & cxl_mbar0_reg_sel & arb_mux;
          cxl_mbar0_arb_mux_reg_id[3] <= #TP (lbc_cdm_addr[11:2] == (12'h004 >> 2)) & cxl_mbar0_reg_sel & arb_mux;
          cxl_mbar0_arb_mux_reg_id[4] <= #TP (lbc_cdm_addr[11:2] == (12'h008 >> 2)) & cxl_mbar0_reg_sel & arb_mux;
       flit_logging_reg_id[0]  <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[0];
       flit_logging_reg_id[1]  <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[1];
       flit_logging_reg_id[2]  <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[2];
       flit_logging_reg_id[3]  <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[3];
       flit_logging_reg_id[4]  <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[4];
       flit_logging_reg_id[5]  <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[5];
       flit_logging_reg_id[6]  <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[6];
       flit_logging_reg_id[7]  <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h01C) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[7];
       flit_logging_reg_id[8]  <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h020) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[8];
       flit_logging_reg_id[9]  <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h024) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[9];
       flit_logging_reg_id[10] <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h028) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[10];
       flit_logging_reg_id[11] <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h02C) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[11];
       flit_logging_reg_id[12] <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h030) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[12];
       flit_logging_reg_id[13] <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h034) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[13];
       flit_logging_reg_id[14] <= #TP (ecfg_reg_id_en && FUNC_NUM == 0 )? ((lbc_cdm_addr[11:2] == (( `FLIT_LOGGING_PTR + 12'h038) >> 2)) & ecfg_reg_sel) : flit_logging_reg_id[14];
       flit_perf_msur_reg_id[0]  <= #TP (ecfg_reg_id_en &&  (FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_PERFORMANCE_MEASUREMENT_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : flit_perf_msur_reg_id[0];
       flit_perf_msur_reg_id[1]  <= #TP (ecfg_reg_id_en &&  (FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_PERFORMANCE_MEASUREMENT_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : flit_perf_msur_reg_id[1];
       flit_perf_msur_reg_id[2]  <= #TP (ecfg_reg_id_en &&  (FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_PERFORMANCE_MEASUREMENT_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : flit_perf_msur_reg_id[2];
       flit_perf_msur_reg_id[3]  <= #TP (ecfg_reg_id_en &&  (FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_PERFORMANCE_MEASUREMENT_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : flit_perf_msur_reg_id[3];
       flit_perf_msur_reg_id[4]  <= #TP (ecfg_reg_id_en &&  (FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_PERFORMANCE_MEASUREMENT_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : flit_perf_msur_reg_id[4];
 
 
       flit_err_inj_reg_id[0]  <= #TP (ecfg_reg_id_en &&  ( FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_ERROR_INJECTION_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : flit_err_inj_reg_id[0];
       flit_err_inj_reg_id[1]  <= #TP (ecfg_reg_id_en &&  ( FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_ERROR_INJECTION_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : flit_err_inj_reg_id[1];
       flit_err_inj_reg_id[2]  <= #TP (ecfg_reg_id_en &&  ( FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_ERROR_INJECTION_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : flit_err_inj_reg_id[2];
       flit_err_inj_reg_id[3]  <= #TP (ecfg_reg_id_en &&  ( FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_ERROR_INJECTION_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : flit_err_inj_reg_id[3];
       flit_err_inj_reg_id[4]  <= #TP (ecfg_reg_id_en &&  ( FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_ERROR_INJECTION_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : flit_err_inj_reg_id[4];
       flit_err_inj_reg_id[5]  <= #TP (ecfg_reg_id_en &&  ( FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_ERROR_INJECTION_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : flit_err_inj_reg_id[5];
       flit_err_inj_reg_id[6]  <= #TP (ecfg_reg_id_en &&  ( FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_ERROR_INJECTION_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : flit_err_inj_reg_id[6];
       flit_err_inj_reg_id[7]  <= #TP (ecfg_reg_id_en &&  ( FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_ERROR_INJECTION_PTR + 12'h01C) >> 2)) & ecfg_reg_sel) : flit_err_inj_reg_id[7];
       flit_err_inj_reg_id[8]  <= #TP (ecfg_reg_id_en &&  ( FUNC_NUM == 0) )? ((lbc_cdm_addr[11:2] == (( `FLIT_ERROR_INJECTION_PTR + 12'h020) >> 2)) & ecfg_reg_sel) : flit_err_inj_reg_id[8];

       end
end


genvar dpc_reg_number;
generate

for(dpc_reg_number = 0; dpc_reg_number<NDPC; dpc_reg_number = dpc_reg_number + 1) begin : gen_dpc_reg_id

always @( posedge cdm_clk_g or negedge non_sticky_rst_n ) begin : dpc_reg_id_PROC
    if ( !non_sticky_rst_n ) begin
        dpc_reg_id[dpc_reg_number] <= #TP 0;
    end else if ((|RCRB) ^ cxl_rcrb_enable) begin
        dpc_reg_id[dpc_reg_number] <= #TP 0;
    end else begin
        dpc_reg_id[dpc_reg_number] <= #TP ecfg_reg_id_en && !upstream_port ? ((lbc_cdm_addr[11:2] == ((`DPC_PTR + (dpc_reg_number*4)) >> 2)) & ecfg_reg_sel) : dpc_reg_id[dpc_reg_number];
    end
end   //always

end   // gen_dpc_reg_id

endgenerate



always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin

  integer depth;

  if(!non_sticky_rst_n)
    tph_reg_id <= #TP 0;
  else
    for (depth = 0; depth <= (2+`TPH_ST_TABLE_DEPTH); depth = depth + 1)
    begin : gen_TPH_REG_ID
      tph_reg_id[depth] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `TPH_PTR + (depth*4)) >> 2)) & ecfg_reg_sel) : tph_reg_id[depth];
    end
end


localparam RTR_PTR = `RTR_PTR;

always @(posedge cdm_clk_g or negedge non_sticky_rst_n) begin : rtr_reg_id_proc

integer depth;

  if(!non_sticky_rst_n)
    rtr_reg_id <= #TP 0;
  else
    for (depth = 0; depth < NRTR; depth = depth + 1)
    begin : gen_RTR_REG_ID
      rtr_reg_id[depth] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `RTR_PTR + (depth*4)) >> 2)) & ecfg_reg_sel) : rtr_reg_id[depth];
    end
end // rtr_reg_id_proc



reg     [15:0]       cfg_ptm_id;                                     // Capability ID
reg     [3:0]        cfg_ptm_ver;                                    // Capability Version
reg     [11:0]       cfg_ptm_next_ptr;                               // Next Capability Offset
reg                  ptm_next_ptr_wr_updated;
wire    [7:0]        ptm_reg_03, ptm_reg_02, ptm_reg_01, ptm_reg_00;         //PCIe header

localparam PTMVSEC_PTR = `PTM_VSEC_PTR;//PTM_REQ_VALUE ? `PTM_REQ_PTR : `PTM_RES_PTR;

generate
  if(FUNC_NUM == 0) begin : gen_ptm_reg_id_func0
    always @(posedge core_clk or negedge non_sticky_rst_n) begin : ptm_reg_id_proc

      integer depth;

      if(!non_sticky_rst_n)
        ptm_reg_id <= #TP 0;
      else
        for (depth = 0; depth < NPTM; depth = depth + 1)
        begin : gen_PTM_REG_ID
          ptm_reg_id[depth] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PTM_PTR + (depth*4)) >> 2)) & ecfg_reg_sel) : ptm_reg_id[depth];
        end
    end // ptm_reg_id_proc

  end else begin                             // All functions different from PF0


      always @(posedge core_clk or negedge non_sticky_rst_n)
      begin
        if(!non_sticky_rst_n) begin
          ptm_reg_id       <= #TP 0;
        end else begin
          ptm_reg_id       <= #TP 0;
        end
      end


  end // if(FUNC_NUM == 0)

endgenerate // gen_ptm_reg_id

// -----------------------------------------------------------------------------
// PTM Extended Capability Header Register
// -----------------------------------------------------------------------------
// ptm_reg_id       - 0
// PCIE Offset      - `PTM_PTR
// length           - 4 byte
// Cfig register    - ptm_reg_03, ptm_reg_02, ptm_reg_01, ptm_reg_00
// Read Only from the Wire.
// -----------------------------------------------------------------------------

localparam  INT_PTM_NEXT_PTR = `PTM_NEXT_PTR;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : cap_hdr_PROC
  if ( !sticky_rst_n ) begin
     cfg_ptm_ver[3:0]       <= #TP `PCIE_PTM_ECAP_VER;
   end else begin
   // Read-Only registers, but writable through DBI, null in a Switch Downstream
     cfg_ptm_ver[3:0]       <= #TP (ptm_reg_id[0] & write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_ptm_ver[3:0];

  end
end //always cap_hdr_PROC

always @( posedge core_clk or negedge sticky_rst_n ) begin 
  if ( !sticky_rst_n ) begin
     cfg_ptm_id[15:0]       <= #TP `PCIE_PTM_ECAP_ID;
   end else begin
   // Read-Only registers, but writable through DBI, null in a Switch Downstream

   cfg_ptm_id[7:0]        <= #TP (ptm_reg_id[0] & write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0]   : cfg_ptm_id[7:0];
   cfg_ptm_id[15:8]       <= #TP (ptm_reg_id[0] & write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8]  : cfg_ptm_id[15:8];
  end
end 

always @( posedge core_clk or negedge sticky_rst_n ) begin : ptm_cap_next_ptr_PROC
  if ( !sticky_rst_n ) begin
      cfg_ptm_next_ptr[11:0]  <= #TP INT_PTM_NEXT_PTR;                // Assume EP linked list at reset.
  end else if (ptm_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
      // Read-Only registers, but writable through DBI
      cfg_ptm_next_ptr[3:0]   <= #TP write_pulse[2] ? lbc_cdm_data[23:20] : cfg_ptm_next_ptr[3:0];
      cfg_ptm_next_ptr[11:4]  <= #TP write_pulse[3] ? lbc_cdm_data[31:24] : cfg_ptm_next_ptr[11:4];
  end else if ((rc_device || pcie_sw_down) && !ptm_next_ptr_wr_updated) begin
      cfg_ptm_next_ptr[11:0]  <= #TP `DM_RP_PTM_NEXT_PTR ;       // If RP or downstream port of SW, then use smaller linked list.
  end else if (!ptm_next_ptr_wr_updated) begin
      cfg_ptm_next_ptr[11:0]  <= #TP (cxl_rcrb_enable && upstream_port) ? ~(|RCRB) ? `CXL_PTM_NEXT_PTR : `RCRB_PTM_NEXT_PTR :  `PTM_NEXT_PTR ;                // Device type could change if crosslink enable is true.
  end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : ptm_cap_hdr_wr_update_PROC
  if ( !sticky_rst_n ) begin
      ptm_next_ptr_wr_updated <= #TP 1'b0;
  end else if (ptm_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |write_pulse[3:2]) begin
      ptm_next_ptr_wr_updated <= #TP 1'b1;
  end
end

assign {ptm_reg_01, ptm_reg_00}      = FUNC_NUM==0 ? cfg_ptm_id : 16'b0;
assign ptm_reg_02[3:0]               = FUNC_NUM==0 ? cfg_ptm_ver : 4'b0;
assign {ptm_reg_03, ptm_reg_02[7:4]} = FUNC_NUM==0 ? cfg_ptm_next_ptr : 11'b0;

always @(posedge cdm_clk_g or negedge non_sticky_rst_n) begin : ptmv_reg_id_proc

integer depth1;

  if(!non_sticky_rst_n)
    ptm_vsec_reg_id <= #TP 0;
  else
    for (depth1 = 0; depth1 < NPTMVSEC; depth1 = depth1 + 1)
    begin : gen_PTMVSEC_REG_ID
      ptm_vsec_reg_id[depth1] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( PTMVSEC_PTR + (depth1*4)) >> 2)) & ecfg_reg_sel) : ptm_vsec_reg_id[depth1];
    end
end // ptmv_reg_id_proc


// The ability to change the next pointer for each function is required but
// the Vendor Specific Capability exists i

  reg     [15:0]        cfg_ptm_vsec_id;                                     // Capability ID
  reg     [3:0]         cfg_ptm_vsec_ver;                                    // Capability Version
  reg     [11:0]        cfg_ptm_vsec_next_ptr;                               // Next Capability Offset
  reg                   ptmvsec_next_ptr_wr_updated;
  wire    [7:0]         ptm_vsec_reg_03, ptm_vsec_reg_02, ptm_vsec_reg_01, ptm_vsec_reg_00;         //PCIe header

always @( posedge core_clk or negedge sticky_rst_n ) begin : ptm_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_ptm_vsec_id[15:0]       <= #TP `PCIE_VSEC_ECAP_ID;
        cfg_ptm_vsec_ver[3:0]       <= #TP `PCIE_VSEC_ECAP_VER;

    end else begin
        // Read-Only registers, but writable through DBI
        cfg_ptm_vsec_id[7:0]        <= #TP (ptm_vsec_reg_id[0] & write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0]    : cfg_ptm_vsec_id[7:0];
        cfg_ptm_vsec_id[15:8]       <= #TP (ptm_vsec_reg_id[0] & write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8]   : cfg_ptm_vsec_id[15:8];
        cfg_ptm_vsec_ver[3:0]       <= #TP (ptm_vsec_reg_id[0] & write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16]  : cfg_ptm_vsec_ver[3:0];

    end
end //always ptm_cap_hdr_PROC


localparam LOCAL_PTM_VSEC_NEXT_PTR = `PTM_VSEC_NEXT_PTR;//PTM_REQ_VALUE ? `PTM_VSEC_NEXT_PTR : `DM_RP_PTM_VSEC_NEXT_PTR;

always @( posedge core_clk or negedge sticky_rst_n ) begin : ptm_vsec_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
      cfg_ptm_vsec_next_ptr[11:0] <= #TP LOCAL_PTM_VSEC_NEXT_PTR;
    end else if (ptm_vsec_reg_id[0] & lbc_cdm_dbi & dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
      cfg_ptm_vsec_next_ptr[3:0]  <= #TP (write_pulse[2]) ? lbc_cdm_data[23:20]  : cfg_ptm_vsec_next_ptr[3:0];
      cfg_ptm_vsec_next_ptr[11:4] <= #TP (write_pulse[3]) ? lbc_cdm_data[31:24]  : cfg_ptm_vsec_next_ptr[11:4];

    end else if((rc_device || pcie_sw_down) && !ptmvsec_next_ptr_wr_updated ) begin
      cfg_ptm_vsec_next_ptr    <= #TP `DM_RP_PTM_VSEC_NEXT_PTR ;      // If RP or downstream port of SW, then use smaller linked list.

    end else if (!ptmvsec_next_ptr_wr_updated ) begin
      cfg_ptm_vsec_next_ptr    <= #TP (cxl_rcrb_enable && upstream_port) ? ~(|RCRB) ? `CXL_PTM_VSEC_NEXT_PTR : `RCRB_PTM_VSEC_NEXT_PTR : LOCAL_PTM_VSEC_NEXT_PTR ;             // If RP or upstream port of SW, then use full linked list. Device type could change if crosslink enable is true.
    end
end //always ptm_vsec cap_hdr_PROC


// If next pointer is modified by a DBI write, then only the Application
// (via another DBI write) is allowed any further update.
always @( posedge core_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptmvsec_next_ptr_wr_updated <= #TP 1'b0;

    end else if (ptm_vsec_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |write_pulse[3:2]) begin
        ptmvsec_next_ptr_wr_updated <= #TP 1'b1;

    end
end


assign {ptm_vsec_reg_01, ptm_vsec_reg_00}       = cfg_ptm_vsec_id;
assign ptm_vsec_reg_02[3:0]                = cfg_ptm_vsec_ver;
assign {ptm_vsec_reg_03, ptm_vsec_reg_02[7:4]}  = cfg_ptm_vsec_next_ptr;






localparam FRSQ_PTR = `FRSQ_PTR;

always @(posedge cdm_clk_g or negedge non_sticky_rst_n) begin : frsq_reg_id_proc

integer depth;

  if(!non_sticky_rst_n)
    frsq_reg_id <= #TP 0;
  else
    for (depth = 0; depth < NFRSQ; depth = depth + 1)
    begin : gen_FRSQ_REG_ID
      frsq_reg_id[depth] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`FRSQ_PTR + (depth*4)) >> 2)) & ecfg_reg_sel) : frsq_reg_id[depth];
    end
end // frsq_reg_id_proc



// -----------------------------------------------------------------------------
// Generate resizable BAR extended register address decodes
// -----------------------------------------------------------------------------

   localparam NUM_RBARS = `CX_NUM_RBARS;

   // LMD: Undriven net Range
   // LJ: All nets are driven by the statement for (i=0; i<=(NUM_RBARS*2); i=i+1
   // leda NTL_CON12 off
   wire [(NUM_RBARS*2):0] rbar_reg_id; // Resizable BAR register ID
   // leda NTL_CON12 on

   generate
     if (NUM_RBARS > 0) begin : gen_rbar_reg_id

       reg [(NUM_RBARS*2):0] rbar_reg_id_r;

       always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_seq_rbar_reg_id
         integer i;

         if (!non_sticky_rst_n) begin
           for (i=0; i<=(NUM_RBARS*2); i=i+1) begin
              rbar_reg_id_r[i] <= #TP 0;
           end
         end else begin
           for (i=0; i<=(NUM_RBARS*2); i=i+1) begin
              rbar_reg_id_r[i] <= #TP (lbc_cdm_addr[11:2] == (( `RBAR_PTR + (12'h004*i)) >> 2)) &
                                       ecfg_reg_sel;
           end
         end
       end
       assign rbar_reg_id = rbar_reg_id_r;
     end else begin : gen_no_rbar_reg_id
       assign rbar_reg_id = 0;
     end
   endgenerate

// -----------------------------------------------------------------------------
// Generate resizable VF BAR extended register address decodes
// -----------------------------------------------------------------------------

   localparam NUM_VF_RBARS = `CX_NUM_VF_RBARS;

   // LMD: Undriven net Range
   // LJ: All nets are driven by the statement for (i=0; i<=(NUM_VF_RBARS*2); i=i+1
   // leda NTL_CON12 off
   wire [(NUM_VF_RBARS*2):0] vf_rbar_reg_id; // Resizable BAR register ID
   // leda NTL_CON12 on

   generate
     if (NUM_VF_RBARS > 0) begin : gen_vf_rbar_reg_id

       reg [(NUM_VF_RBARS*2):0] vf_rbar_reg_id_r;

       always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_seq_vf_rbar_reg_id
         integer i;

         if (!non_sticky_rst_n) begin
           for (i=0; i<=(NUM_VF_RBARS*2); i=i+1) begin
              vf_rbar_reg_id_r[i] <= #TP 0;
           end
         end else begin
           for (i=0; i<=(NUM_VF_RBARS*2); i=i+1) begin
              vf_rbar_reg_id_r[i] <= #TP (lbc_cdm_addr[11:2] == (( `VF_RBAR_PTR + (12'h004*i)) >> 2)) &

                                       ecfg_reg_sel;
           end
         end
       end
       assign vf_rbar_reg_id = vf_rbar_reg_id_r;
     end else begin : gen_no_vf_rbar_reg_id
       assign vf_rbar_reg_id = 0;
     end
   endgenerate


// =============================================================================
// Configuration Register Read Operation
// =============================================================================
reg     [31:0]  vc_reg_data;

wire dbi_ro_wr_en;
wire int_lbc_cdm_dbi;
assign int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;


// Extension Configuration registers
// read PCI cfg space registers
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
  if (!non_sticky_rst_n)
        ecfg_reg_data <= #TP 32'b0;
  else 
  begin
    if (|err_reg_id) 
       ecfg_reg_data <= #TP err_reg_data;
    else if (|vc_reg_id)
       ecfg_reg_data <= #TP vc_reg_data ;
    else if (|sn_reg_id)
       ecfg_reg_data <= #TP sn_reg_data;
    else if (|pb_reg_id)
       ecfg_reg_data <= #TP pb_reg_data ;
    else if (|rbar_reg_id)
       ecfg_reg_data <= #TP rbar_reg_data;
    else if (|vf_rbar_reg_id)
       ecfg_reg_data <= #TP vf_rbar_reg_data;
    else if (|ras_reg_id)
       ecfg_reg_data <= #TP ras_reg_data;
    else if (|spcie_reg_id)
       ecfg_reg_data <= #TP spcie_reg_data;
    else if (|pl16g_reg_id)
       ecfg_reg_data <= #TP pl16g_reg_data;
    else if (|margin_reg_id)
       ecfg_reg_data <= #TP margin_reg_data;
    else if (|pl32g_reg_id)
       ecfg_reg_data <= #TP pl32g_reg_data;
    else if (|pl64g_reg_id)
       ecfg_reg_data <= #TP pl64g_reg_data;
    else if (|l1sub_reg_id)
       ecfg_reg_data <= #TP l1sub_reg_data;
    else if (|tph_reg_id)
       ecfg_reg_data <= #TP tph_reg_data;
    else if (|ats_reg_id)
       ecfg_reg_data <= #TP ats_reg_data;
    else if (|acs_reg_id)
       ecfg_reg_data <= #TP acs_reg_data;
    else if (|prs_reg_id)
       ecfg_reg_data <= #TP prs_reg_data;
    else if (|ltr_reg_id)
       ecfg_reg_data <= #TP ltr_reg_data;
    else if (|dev3_reg_id)
       ecfg_reg_data <= #TP dev3_reg_data;
    else if (|pasid_reg_id)
       ecfg_reg_data <= #TP pasid_reg_data;
    else if (|dpc_reg_id)
       ecfg_reg_data <= #TP dpc_reg_data;
    else if (|frsq_reg_id)
       ecfg_reg_data <= #TP frsq_reg_data;
    else if (|ptm_reg_id) begin
      if (ptm_reg_id[0])
       ecfg_reg_data <= #TP {ptm_reg_03, ptm_reg_02, ptm_reg_01, ptm_reg_00};
       else
       ecfg_reg_data <= #TP ptm_reg_data;
     end

    else if (|ptm_vsec_reg_id) begin
      if (ptm_vsec_reg_id[0])
         ecfg_reg_data <= #TP {ptm_vsec_reg_03, ptm_vsec_reg_02, ptm_vsec_reg_01, ptm_vsec_reg_00};
       else
         ecfg_reg_data <= #TP ptm_vsec_reg_data;
     end
    else if (|vsecdma_reg_id)
       ecfg_reg_data <= #TP vsecdma_reg_data;
    else if (|rtr_reg_id)
       ecfg_reg_data <= #TP rtr_reg_data;
    else if (|rasdes_reg_id)
       ecfg_reg_data <= #TP rasdes_reg_data;
    else if (|dlink_reg_id)
       ecfg_reg_data <= #TP dlink_reg_data;
    else if (|cxl_reg_id)
       ecfg_reg_data <= #TP cxl_reg_data;
    else if (|cxl_rcrb_reg_id)
       ecfg_reg_data <= #TP cxl_rcrb_reg_data;
    else if (|cxl_2_0_ext_reg_id)
       ecfg_reg_data <= #TP cxl_2_0_ext_reg_data;

    else if (|cxl_reg_locator_reg_id)
       ecfg_reg_data <= #TP cxl_reg_locator_reg_data;
    else if (|cxl_gpf_port_reg_id)
       ecfg_reg_data <= #TP cxl_gpf_port_reg_data;
    else if (|cxl_gpf_device_reg_id)
       ecfg_reg_data <= #TP cxl_gpf_device_reg_data;
    else if (|flit_logging_reg_id)
       ecfg_reg_data <= #TP flit_logging_reg_data;
    else if (|flit_perf_msur_reg_id)
       ecfg_reg_data <= #TP flit_perf_msur_reg_data;
    else if (|flit_err_inj_reg_id)
       ecfg_reg_data <= #TP flit_err_inj_reg_data;
    else
       ecfg_reg_data <= #TP `PCIE_UNUSED_RESPONSE;
  end
end

generate
if(FUNC_NUM==0 && VC_EN) begin : gen_vc_reg_data
  always @(posedge core_clk or negedge non_sticky_rst_n)
  begin
    if (!non_sticky_rst_n)
        vc_reg_data <= #TP 32'b0;
    else
        if (read_pulse) begin


            unique case (1'b1)

            vc_reg_id[ 0] : vc_reg_data <= #TP {ecfg_reg_03, ecfg_reg_02, ecfg_reg_01, ecfg_reg_00};  // VC Header for Function 0 only

            vc_reg_id[ 1] : vc_reg_data <= #TP {ecfg_reg_07, ecfg_reg_06, ecfg_reg_05, ecfg_reg_04};
            vc_reg_id[ 2] : vc_reg_data <= #TP {ecfg_reg_11, ecfg_reg_10, ecfg_reg_09, ecfg_reg_08};
            vc_reg_id[ 3] : vc_reg_data <= #TP {ecfg_reg_15, ecfg_reg_14, ecfg_reg_13, ecfg_reg_12};
            // VC0
            vc_reg_id[ 4] : vc_reg_data <= #TP {ecfg_reg_19, ecfg_reg_18, ecfg_reg_17, ecfg_reg_16};
            vc_reg_id[ 5] : vc_reg_data <= #TP {ecfg_reg_23, ecfg_reg_22, ecfg_reg_21, ecfg_reg_20};
            vc_reg_id[ 6] : vc_reg_data <= #TP {ecfg_reg_27, ecfg_reg_26, ecfg_reg_25, ecfg_reg_24};

            // VC1
            vc_reg_id[ 7] : vc_reg_data <= #TP {ecfg_reg_31, ecfg_reg_30, ecfg_reg_29, ecfg_reg_28};
            vc_reg_id[ 8] : vc_reg_data <= #TP {ecfg_reg_35, ecfg_reg_34, ecfg_reg_33, ecfg_reg_32};
            vc_reg_id[ 9] : vc_reg_data <= #TP {ecfg_reg_39, ecfg_reg_38, ecfg_reg_37, ecfg_reg_36};
            // VC2
            vc_reg_id[10] : vc_reg_data <= #TP {ecfg_reg_43, ecfg_reg_42, ecfg_reg_41, ecfg_reg_40};
            vc_reg_id[11] : vc_reg_data <= #TP {ecfg_reg_47, ecfg_reg_46, ecfg_reg_45, ecfg_reg_44};
            vc_reg_id[12] : vc_reg_data <= #TP {ecfg_reg_51, ecfg_reg_50, ecfg_reg_49, ecfg_reg_48};
            // VC3
            vc_reg_id[13] : vc_reg_data <= #TP {ecfg_reg_55, ecfg_reg_54, ecfg_reg_53, ecfg_reg_52};
            vc_reg_id[14] : vc_reg_data <= #TP {ecfg_reg_59, ecfg_reg_58, ecfg_reg_57, ecfg_reg_56};
            vc_reg_id[15] : vc_reg_data <= #TP {ecfg_reg_63, ecfg_reg_62, ecfg_reg_61, ecfg_reg_60};
            // VC4
            vc_reg_id[16] : vc_reg_data <= #TP {ecfg_reg_67, ecfg_reg_66, ecfg_reg_65, ecfg_reg_64};
            vc_reg_id[17] : vc_reg_data <= #TP {ecfg_reg_71, ecfg_reg_70, ecfg_reg_69, ecfg_reg_68};
            vc_reg_id[18] : vc_reg_data <= #TP {ecfg_reg_75, ecfg_reg_74, ecfg_reg_73, ecfg_reg_72};
            // VC5
            vc_reg_id[19] : vc_reg_data <= #TP {ecfg_reg_79, ecfg_reg_78, ecfg_reg_77, ecfg_reg_76};
            vc_reg_id[20] : vc_reg_data <= #TP {ecfg_reg_83, ecfg_reg_82, ecfg_reg_81, ecfg_reg_80};
            vc_reg_id[21] : vc_reg_data <= #TP {ecfg_reg_87, ecfg_reg_86, ecfg_reg_85, ecfg_reg_84};
            // VC6
            vc_reg_id[22] : vc_reg_data <= #TP {ecfg_reg_91, ecfg_reg_90, ecfg_reg_89, ecfg_reg_88};
            vc_reg_id[23] : vc_reg_data <= #TP {ecfg_reg_95, ecfg_reg_94, ecfg_reg_93, ecfg_reg_92};
            vc_reg_id[24] : vc_reg_data <= #TP {ecfg_reg_99, ecfg_reg_98, ecfg_reg_97, ecfg_reg_96};
            // VC7
            vc_reg_id[25] : vc_reg_data <= #TP {ecfg_reg_103, ecfg_reg_102, ecfg_reg_101, ecfg_reg_100};
            vc_reg_id[26] : vc_reg_data <= #TP {ecfg_reg_107, ecfg_reg_106, ecfg_reg_105, ecfg_reg_104};
            vc_reg_id[27] : vc_reg_data <= #TP {ecfg_reg_111, ecfg_reg_110, ecfg_reg_109, ecfg_reg_108};

            default:        vc_reg_data <= #TP `PCIE_UNUSED_RESPONSE;
            endcase
        end
        else
            vc_reg_data <= #TP vc_reg_data;
  end // always @ (posedge core_clk or negedge non_sticky_rst_n)

end

else begin : gen_vc_reg_data //generate
always @(posedge core_clk or negedge non_sticky_rst_n)
  begin
    if (!non_sticky_rst_n)
        vc_reg_data <= #TP 32'b0;
    else
        vc_reg_data <= #TP {ecfg_reg_03, ecfg_reg_02, 16'h0};     // Null Capability for all other functions

  end

end // block: gen_vc_reg_data

endgenerate


always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n)
        sn_reg_data <= #TP 32'b0;
    else
        if (read_pulse & SN_EN) begin

            unique case (1'b1)
            // Device Serial Number
            sn_reg_id[0] : sn_reg_data  <= #TP {sn_reg_03, sn_reg_02, sn_reg_01, sn_reg_00};
            sn_reg_id[1] : sn_reg_data  <= #TP {sn_reg_07, sn_reg_06, sn_reg_05, sn_reg_04};
            sn_reg_id[2] : sn_reg_data  <= #TP {sn_reg_11, sn_reg_10, sn_reg_09, sn_reg_08};
            default      : sn_reg_data  <= #TP `PCIE_UNUSED_RESPONSE;
            endcase
        end
        else
            sn_reg_data <= #TP sn_reg_data;
end

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n)
        pb_reg_data <= #TP 32'b0;
    else
        if (read_pulse & PB_EN) begin

            unique case (1'b1)
            // Power Budgeting
            pb_reg_id[0] : pb_reg_data  <= #TP {pb_reg_03, pb_reg_02, pb_reg_01, pb_reg_00};
            pb_reg_id[1] : pb_reg_data  <= #TP {pb_reg_07, pb_reg_06, pb_reg_05, pb_reg_04};
            pb_reg_id[2] : pb_reg_data  <= #TP {pb_reg_11, pb_reg_10, pb_reg_09, pb_reg_08};
            pb_reg_id[3] : pb_reg_data  <= #TP {pb_reg_15, pb_reg_14, pb_reg_13, pb_reg_12};
            default      : pb_reg_data  <= #TP `PCIE_UNUSED_RESPONSE;
            endcase
        end
        else
            pb_reg_data <= #TP pb_reg_data;
end



// ack one cycle after lbc_cdm_cs is asserted
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        ecfg_reg_ack            <= #TP 0;
        ecfg_reg_sel_d          <= #TP 0;
        ecfg_reg_sel_dd         <= #TP 0;

        write_pulse             <= #TP 0;
        cxl_mbar0_write_pulse <= #TP 0;
        cxl_mbar0_reg_ack     <= #TP 0;
        cxl_mbar0_reg_sel_d   <= #TP 0;
        read_pulse              <= #TP 0;
    end else begin
        ecfg_reg_ack            <= #TP  (
                                  |rasdes_reg_id ? rasdes_reg_ack :
                                  |ras_reg_id ? ras_reg_ack :
                                  ecfg_reg_sel_d & ecfg_reg_sel_dd & ecfg_reg_sel )
                              ;
        ecfg_reg_sel_d  <= #TP ecfg_reg_sel;
        ecfg_reg_sel_dd <= #TP ecfg_reg_sel_d;
        write_pulse     <= #TP (ecfg_reg_sel & ~ecfg_reg_sel_d) ? lbc_cdm_wr : 4'b0;
        read_pulse      <= #TP ecfg_reg_sel & ~ecfg_reg_sel_d & (~|lbc_cdm_wr);
        cxl_mbar0_write_pulse <= #TP (cxl_mbar0_reg_sel & ~cxl_mbar0_reg_sel_d) ? lbc_cdm_wr : 4'b0;
        cxl_mbar0_reg_ack     <= #TP cxl_mbar0_reg_sel_d & cxl_mbar0_reg_sel;
        cxl_mbar0_reg_sel_d   <= #TP cxl_mbar0_reg_sel;
    end
end

// =============================================================================
// VC Capability
// =============================================================================
reg     [7:0]   vc_enable;                      // VC enable - bit 0 is always 1
reg     [6:0]   r_vc_enable;                    // VC enable - excluding bit 0
wire    [8:0]   vc_neg_pending;

assign vc_neg_pending = {{(9-NVC){1'b0}}, (~rtlh_fc_init_status & vc_enable[NVC-1:0])};

// -----------------------------------------------------------------------------
// Virtual Channel Enhanced Capability Header
// vc_reg_id        - 0
// PCIE Offset      - `VC_PTR
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_00, ecfg_reg_01, ecfg_reg_02, ecfg_reg_03
// -----------------------------------------------------------------------------

reg [15:0]  cfg_vc_id;          // VC Capability ID
reg [3:0]   cfg_vc_ver;         // VC Capability Version
reg [11:0]  cfg_vc_next_ptr;    // VC Next Capability Offset
reg         vc_next_ptr_wr_updated;    // Asserted when VC Capability header has been changed by a DBI write

// Capabilities such as RBAR should not
// be visible to a DM product in Root Port mode; hence, when rc_device
// is true then the next pointer is in a smaller linked list.

assign {ecfg_reg_01, ecfg_reg_00}       = cfg_vc_id;
assign ecfg_reg_02[3:0]                 = cfg_vc_ver;
assign {ecfg_reg_03, ecfg_reg_02[7:4]}  = cfg_vc_next_ptr;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : vc_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_vc_id[15:0]       <= #TP `PCIE_VC_ECAP_ID;
        cfg_vc_ver[3:0]       <= #TP `PCIE_VC_ECAP_VER;
    end else if (vc_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_vc_id[7:0]        <= #TP write_pulse[0] ? lbc_cdm_data[7:0] : cfg_vc_id[7:0];
        cfg_vc_id[15:8]       <= #TP write_pulse[1] ? lbc_cdm_data[15:8] : cfg_vc_id[15:8];
        cfg_vc_ver[3:0]       <= #TP write_pulse[2] ? lbc_cdm_data[19:16] : cfg_vc_ver[3:0];
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : vc_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_vc_next_ptr[11:0]  <= #TP `VC_NEXT_PTR;                // Assume EP linked list at reset.
    end else if (vc_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_vc_next_ptr[3:0]   <= #TP write_pulse[2] ? lbc_cdm_data[23:20] : cfg_vc_next_ptr[3:0];
        cfg_vc_next_ptr[11:4]  <= #TP write_pulse[3] ? lbc_cdm_data[31:24] : cfg_vc_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !vc_next_ptr_wr_updated) begin
        cfg_vc_next_ptr[11:0]  <= #TP `DM_RP_VC_NEXT_PTR ;       // If RP or downstream port of SW, then use smaller linked list.
    end else if (!vc_next_ptr_wr_updated) begin
        cfg_vc_next_ptr[11:0]  <= #TP (cxl_rcrb_enable && upstream_port) ? (|RCRB) ? `RCRB_VC_NEXT_PTR : `CXL_VC_NEXT_PTR :  `VC_NEXT_PTR ;                // Device type could change if crosslink enable is true.
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : vc_cap_hdr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        vc_next_ptr_wr_updated <= #TP 1'b0;
    end else if (vc_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |write_pulse[3:2]) begin
        vc_next_ptr_wr_updated <= #TP 1'b1;
    end
end


// -----------------------------------------------------------------------------
// Port VC Capability Register 1
// vc_reg_id        - 1
// PCIE Offset      - `VC_PTR + 04h
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_04, ecfg_reg_05, ecfg_reg_06, ecfg_reg_07
// -----------------------------------------------------------------------------
// set to 0 for Root Port and Endpoint
wire    [1:0]   vc_ref_clk;
assign vc_ref_clk                = switch_device ? `DEFAULT_VC_REF_CLK          : 2'b0;
wire    [1:0]   port_arb_table_entry_size;
assign port_arb_table_entry_size = switch_device ? `DEFAULT_PORT_ARB_TABLE_SIZE : 2'b0;

assign ecfg_reg_04[7:3] = {1'b0, cfg_lpvc, 1'b0};           // Low Priority Extended VC (LPVC) Count
assign ecfg_reg_04[2:0] = `DEFAULT_EXT_VC_CNT;
//VCS coverage off
assign ecfg_reg_05 = {4'b0,                                 // RsvdP
                      port_arb_table_entry_size,            // Port Arbitration Table Size
                      vc_ref_clk};                          // ref clk for VC that support time-based WRR
//VCS coverage on
assign ecfg_reg_06 = 8'b0;                                  // RsvdP
assign ecfg_reg_07 = 8'b0;                                  // RsvdP

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (~sticky_rst_n) begin
        cfg_lpvc    <= #TP `DEFAULT_LOW_PRI_EXT_VC_CNT;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_lpvc    <= #TP (vc_reg_id[1] & write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[6:4] : cfg_lpvc;
    end
end

// -----------------------------------------------------------------------------
// Port VC Capability Register 2
// vc_reg_id        - 2
// PCIE Offset      - `VC_PTR + 08h
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_08, ecfg_reg_09, ecfg_reg_10, ecfg_reg_11
// -----------------------------------------------------------------------------
reg[7:0] cfg_vc_arb_cap;
assign ecfg_reg_08 = cfg_vc_arb_cap;                             // VC Arbitration Capability
assign ecfg_reg_09 = 8'b0;                                  // RsvdP
assign ecfg_reg_10 = 8'b0;                                  // RsvdP
assign ecfg_reg_11 = `DEFAULT_VC_ARB_TABLE_OFFSET;          // VC Arbitration Table Offset

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        cfg_vc_arb_cap       <= #TP `DEFAULT_VC_ARB_32;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_vc_arb_cap[3:0]  <= #TP (vc_reg_id[2] & write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[3:0] : cfg_vc_arb_cap[3:0];
        cfg_vc_arb_cap[7:4]  <= #TP 0;                           // Reserved
    end
end

// -----------------------------------------------------------------------------
// Port VC Control Register
// vc_reg_id        - 3
// PCIE Offset      - `VC_PTR + 0Ch
// length           - 2 byte
// default value    -
// Cfig register    - ecfg_reg_12, ecfg_reg_13
// -----------------------------------------------------------------------------

assign          ecfg_reg_12 = {4'h0, cfg_vc_arb_sel, 1'b0}; // bit 0 always return 0 when read
assign          ecfg_reg_13 = 8'h0;                         // RsvdP

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_vc_arb_sel  <= #TP 0;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_vc_arb_sel  <= #TP (vc_reg_id[3] & write_pulse[0]) ? lbc_cdm_data[3:1] : cfg_vc_arb_sel;

    end
end

// -----------------------------------------------------------------------------
// Port VC status Register
// vc_reg_id        - 3
// PCIE Offset      - `VC_PTR + 0Eh
// length           - 2 byte
// default value    -
// Cfig register    - ecfg_reg_14, ecfg_reg_15
// -----------------------------------------------------------------------------
wire        vc_table_status;
assign vc_table_status = 0;                            // 0 since no arbitration table present

//VCS coverage off
assign      ecfg_reg_14     = {7'b0,                        // RsvdP
                               vc_table_status};            // VC Arbitration Table Status
//VCS coverage on
assign      ecfg_reg_15     = 8'b0;                         // RsvdP

// =============================================================================
// VC0 Resource Capability Register
// vc_reg_id        - 4
// PCIE Offset      - `VC_PTR + 10h
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_16, ecfg_reg_17, ecfg_reg_18, ecfg_reg_19
// -----------------------------------------------------------------------------
assign ecfg_reg_16 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC0 : 8'b0;
assign ecfg_reg_17 = {`DEFAULT_REJECT_NO_SNOOP_VC0,         // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC0,                 // When set, only support AS packet traffic
                      6'b0};                                // RsvdP
assign ecfg_reg_18 = {1'b0,                                 // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC0};         // Maximum Time Slot
assign ecfg_reg_19 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC0 : 8'b0;

// -----------------------------------------------------------------------------
// VC0 Resource Control Register
// vc_reg_id        - 5
// PCIE Offset      - `VC_PTR + 14h
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_20, ecfg_reg_21, ecfg_reg_22, ecfg_reg_23
// -----------------------------------------------------------------------------
reg     [2:0]   vc0_port_arb_sel;
reg     [7:0]   tc_vc0_map;
assign          ecfg_reg_20         = {tc_vc0_map[7:1], 1'b1};
assign          ecfg_reg_21         = 8'h0;                 // RsvdP
assign          ecfg_reg_22         = {4'h0, 3'h0, 1'b0};
reg             load_port0_arb_table;                       // No table supported, not used
assign          ecfg_reg_23         = 8'h80;

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        tc_vc0_map          <= #TP 8'hFF;
        load_port0_arb_table<= #TP 0;
        vc0_port_arb_sel    <= #TP 0;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // Bit 0 is read only - must be set to 1 only for VC0.
        tc_vc0_map[7:1]     <= #TP (vc_reg_id[5] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc0_map[7:1];
        tc_vc0_map[0]       <= #TP 1'b1;
        load_port0_arb_table<= #TP (vc_reg_id[5] & write_pulse[2]) ? lbc_cdm_data[16] : load_port0_arb_table;
        vc0_port_arb_sel    <= #TP (vc_reg_id[5] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc0_port_arb_sel;
    end
end

// -----------------------------------------------------------------------------
// VC0 Resource Status Register
// vc_reg_id        - 6
// PCIE Offset      - `VC_PTR + 18h
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_24, ecfg_reg_25, ecfg_reg_26, ecfg_reg_27
// -----------------------------------------------------------------------------
assign   ecfg_reg_24 = 8'b0;                                // RsvdP
assign   ecfg_reg_25 = 8'b0;                                // RsvdP
assign   ecfg_reg_26 = {6'b0, vc_neg_pending[0], 1'b0};
assign   ecfg_reg_27 = 8'b0;                                // RsvdP




// =============================================================================
// VC0 was special, but VC1-7 is the same structure/characteristics
// =============================================================================
reg [7:1]   tc_vc_map[7:0];                                 // bit 0 is always 0
reg [7:1]   load_port_arb_table;                            // Not supported
reg [2:0]   vc_port_arb_sel[7:1];                           // Arbitration select, only 000 is supported
reg [2:0]   vc_id[7:1];                                     // VC ID - structure 0 is always 0

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
            tc_vc_map[1]            <= #TP 0;
            load_port_arb_table[1]  <= #TP 0;
            vc_port_arb_sel[1]      <= #TP 0;
            vc_id[1]                <= #TP 0;
            tc_vc_map[2]            <= #TP 0;
            load_port_arb_table[2]  <= #TP 0;
            vc_port_arb_sel[2]      <= #TP 0;
            vc_id[2]                <= #TP 0;
            tc_vc_map[3]            <= #TP 0;
            load_port_arb_table[3]  <= #TP 0;
            vc_port_arb_sel[3]      <= #TP 0;
            vc_id[3]                <= #TP 0;
            tc_vc_map[4]            <= #TP 0;
            load_port_arb_table[4]  <= #TP 0;
            vc_port_arb_sel[4]      <= #TP 0;
            vc_id[4]                <= #TP 0;
            tc_vc_map[5]            <= #TP 0;
            load_port_arb_table[5]  <= #TP 0;
            vc_port_arb_sel[5]      <= #TP 0;
            vc_id[5]                <= #TP 0;
            tc_vc_map[6]            <= #TP 0;
            load_port_arb_table[6]  <= #TP 0;
            vc_port_arb_sel[6]      <= #TP 0;
            vc_id[6]                <= #TP 0;
            tc_vc_map[7]            <= #TP 0;
            load_port_arb_table[7]  <= #TP 0;
            vc_port_arb_sel[7]      <= #TP 0;
            vc_id[7]                <= #TP 0;
            tc_vc_map[0]            <= #TP 0;
    end else begin
        tc_vc_map[0]                <= #TP tc_vc0_map[7:1];
        if (VC_EN) begin
            tc_vc_map[1]            <= #TP (vc_reg_id[8] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[1];
            load_port_arb_table[1]  <= #TP (vc_reg_id[8] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[1];
            vc_port_arb_sel[1]      <= #TP (vc_reg_id[8] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[1];
            vc_id[1]                <= #TP (vc_reg_id[8] & write_pulse[3] & ~vc_enable[1]) ? lbc_cdm_data[26:24] : vc_id[1];

            tc_vc_map[2]            <= #TP (vc_reg_id[11] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[2];
            load_port_arb_table[2]  <= #TP (vc_reg_id[11] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[2];
            vc_port_arb_sel[2]      <= #TP (vc_reg_id[11] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[2];
            vc_id[2]                <= #TP (vc_reg_id[11] & write_pulse[3] & ~vc_enable[2]) ? lbc_cdm_data[26:24] : vc_id[2];

            tc_vc_map[3]            <= #TP (vc_reg_id[14] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[3];
            load_port_arb_table[3]  <= #TP (vc_reg_id[14] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[3];
            vc_port_arb_sel[3]      <= #TP (vc_reg_id[14] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[3];
            vc_id[3]                <= #TP (vc_reg_id[14] & write_pulse[3] & ~vc_enable[3]) ? lbc_cdm_data[26:24] : vc_id[3];

            tc_vc_map[4]            <= #TP (vc_reg_id[17] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[4];
            load_port_arb_table[4]  <= #TP (vc_reg_id[17] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[4];
            vc_port_arb_sel[4]      <= #TP (vc_reg_id[17] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[4];
            vc_id[4]                <= #TP (vc_reg_id[17] & write_pulse[3] & ~vc_enable[4]) ? lbc_cdm_data[26:24] : vc_id[4];

            tc_vc_map[5]            <= #TP (vc_reg_id[20] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[5];
            load_port_arb_table[5]  <= #TP (vc_reg_id[20] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[5];
            vc_port_arb_sel[5]      <= #TP (vc_reg_id[20] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[5];
            vc_id[5]                <= #TP (vc_reg_id[20] & write_pulse[3] & ~vc_enable[5]) ? lbc_cdm_data[26:24] : vc_id[5];

            tc_vc_map[6]            <= #TP (vc_reg_id[23] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[6];
            load_port_arb_table[6]  <= #TP (vc_reg_id[23] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[6];
            vc_port_arb_sel[6]      <= #TP (vc_reg_id[23] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[6];
            vc_id[6]                <= #TP (vc_reg_id[23] & write_pulse[3] & ~vc_enable[6]) ? lbc_cdm_data[26:24] : vc_id[6];

            tc_vc_map[7]            <= #TP (vc_reg_id[26] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[7];
            load_port_arb_table[7]  <= #TP (vc_reg_id[26] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[7];
            vc_port_arb_sel[7]      <= #TP (vc_reg_id[26] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[7];
            vc_id[7]                <= #TP (vc_reg_id[26] & write_pulse[3] & ~vc_enable[7]) ? lbc_cdm_data[26:24] : vc_id[7];
        end
        else begin
            tc_vc_map[1]            <= #TP 0;
            load_port_arb_table[1]  <= #TP 0;
            vc_port_arb_sel[1]      <= #TP 0;
            vc_id[1]                <= #TP 0;
            tc_vc_map[2]            <= #TP 0;
            load_port_arb_table[2]  <= #TP 0;
            vc_port_arb_sel[2]      <= #TP 0;
            vc_id[2]                <= #TP 0;
            tc_vc_map[3]            <= #TP 0;
            load_port_arb_table[3]  <= #TP 0;
            vc_port_arb_sel[3]      <= #TP 0;
            vc_id[3]                <= #TP 0;
            tc_vc_map[4]            <= #TP 0;
            load_port_arb_table[4]  <= #TP 0;
            vc_port_arb_sel[4]      <= #TP 0;
            vc_id[4]                <= #TP 0;
            tc_vc_map[5]            <= #TP 0;
            load_port_arb_table[5]  <= #TP 0;
            vc_port_arb_sel[5]      <= #TP 0;
            vc_id[5]                <= #TP 0;
            tc_vc_map[6]            <= #TP 0;
            load_port_arb_table[6]  <= #TP 0;
            vc_port_arb_sel[6]      <= #TP 0;
            vc_id[6]                <= #TP 0;
            tc_vc_map[7]            <= #TP 0;
            load_port_arb_table[7]  <= #TP 0;
            vc_port_arb_sel[7]      <= #TP 0;
            vc_id[7]                <= #TP 0;
        end
    end
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
  if (!non_sticky_rst_n) begin
    r_vc_enable               <= #TP 0;
  end else if (!upstream_port && !rdlh_link_up) begin
    r_vc_enable               <= #TP 0;
  end else begin
    if (VC_EN) begin
      r_vc_enable[0]            <= #TP (vc_reg_id[8] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[0];
      r_vc_enable[1]            <= #TP (vc_reg_id[11] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[1];
      r_vc_enable[2]            <= #TP (vc_reg_id[14] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[2];
      r_vc_enable[3]            <= #TP (vc_reg_id[17] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[3];
      r_vc_enable[4]            <= #TP (vc_reg_id[20] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[4];
      r_vc_enable[5]            <= #TP (vc_reg_id[23] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[5];
      r_vc_enable[6]            <= #TP (vc_reg_id[26] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[6];
    end
    else begin
      r_vc_enable               <= #TP 0;
    end
  end
end

assign vc_enable = {r_vc_enable, 1'b1};

// VC1
assign ecfg_reg_28 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC1 : 8'b0;
assign ecfg_reg_29 = {`DEFAULT_REJECT_NO_SNOOP_VC1,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC1,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_30 = {1'b0,                                             // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC1};                     // Maximum Time Slot
assign ecfg_reg_31 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC1 : 8'b0;
assign ecfg_reg_32 = {tc_vc_map[1], 1'b0};
assign ecfg_reg_33 = 8'h0;
assign ecfg_reg_34 = {4'h0, vc_port_arb_sel[1], 1'b0};
assign ecfg_reg_35 = {vc_enable[1], 4'h0, vc_id[1]};
assign ecfg_reg_36 = 8'b0;                                              // RsvdP
assign ecfg_reg_37 = 8'b0;                                              // RsvdP
assign ecfg_reg_38 = {6'b0, vc_neg_pending[1], 1'b0};
assign ecfg_reg_39 = 8'b0;
// VC2
assign ecfg_reg_40 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC2 : 8'b0;
assign ecfg_reg_41 = {`DEFAULT_REJECT_NO_SNOOP_VC2,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC2,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_42 = {1'b0,                                             // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC2};                     // Maximum Time Slot
assign ecfg_reg_43 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC2 : 8'b0;
assign ecfg_reg_44 = {tc_vc_map[2], 1'b0};
assign ecfg_reg_45 = 8'h0;
assign ecfg_reg_46 = {4'h0, vc_port_arb_sel[2], 1'b0};
assign ecfg_reg_47 = {vc_enable[2], 4'h0, vc_id[2]};
assign ecfg_reg_48 = 8'b0;                                              // RsvdP
assign ecfg_reg_49 = 8'b0;                                              // RsvdP
assign ecfg_reg_50 = {6'b0, vc_neg_pending[2], 1'b0};
assign ecfg_reg_51 = 8'b0;
// VC3
assign ecfg_reg_52 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC3 : 8'b0;
assign ecfg_reg_53 = {`DEFAULT_REJECT_NO_SNOOP_VC3,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC3,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_54 = {1'b0,                                             // RsvdP
                    `DEFAULT_MAX_TIME_SLOTS_VC3};                       // Maximum Time Slot
assign ecfg_reg_55 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC3 : 8'b0;
assign ecfg_reg_56 = {tc_vc_map[3], 1'b0};
assign ecfg_reg_57 = 8'h0;
assign ecfg_reg_58 = {4'h0, vc_port_arb_sel[3], 1'b0};
assign ecfg_reg_59 = {vc_enable[3], 4'h0, vc_id[3]};
assign ecfg_reg_60 = 8'b0;                                              // RsvdP
assign ecfg_reg_61 = 8'b0;                                              // RsvdP
assign ecfg_reg_62 = {6'b0, vc_neg_pending[3], 1'b0};
assign ecfg_reg_63 = 8'b0;
// VC4
assign ecfg_reg_64 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC4 : 8'b0;
assign ecfg_reg_65 = {`DEFAULT_REJECT_NO_SNOOP_VC4,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC4,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_66 = {1'b0,                                             // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC4};                     // Maximum Time Slot
assign ecfg_reg_67 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC4 : 8'b0;
assign ecfg_reg_68 = {tc_vc_map[4], 1'b0};
assign ecfg_reg_69 = 8'h0;
assign ecfg_reg_70 = {4'h0, vc_port_arb_sel[4], 1'b0};
assign ecfg_reg_71 = {vc_enable[4], 4'h0, vc_id[4]};
assign ecfg_reg_72 = 8'b0;                                              // RsvdP
assign ecfg_reg_73 = 8'b0;                                              // RsvdP
assign ecfg_reg_74 = {6'b0, vc_neg_pending[4], 1'b0};
assign ecfg_reg_75 = 8'b0;
// VC5
assign ecfg_reg_76 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC5 : 8'b0;
assign ecfg_reg_77 = {`DEFAULT_REJECT_NO_SNOOP_VC5,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC5,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_78 = {1'b0,                                             // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC5};                     // Maximum Time Slot
assign ecfg_reg_79 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC5 : 8'b0;
assign ecfg_reg_80 = {tc_vc_map[5], 1'b0};
assign ecfg_reg_81 = 8'h0;
assign ecfg_reg_82 = {4'h0, vc_port_arb_sel[5], 1'b0};
assign ecfg_reg_83 = {vc_enable[5], 4'h0, vc_id[5]};
assign ecfg_reg_84 = 8'b0;                                              // RsvdP
assign ecfg_reg_85 = 8'b0;                                              // RsvdP
assign ecfg_reg_86 = {6'b0, vc_neg_pending[5], 1'b0};
assign ecfg_reg_87 = 8'b0;
// VC6
assign ecfg_reg_88 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC6 : 8'b0;
assign ecfg_reg_89 = {`DEFAULT_REJECT_NO_SNOOP_VC6,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC6,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_90 = {1'b0,                                             // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC6};                     // Maximum Time Slot
assign ecfg_reg_91 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC6 : 8'b0;
assign ecfg_reg_92 = {tc_vc_map[6], 1'b0};
assign ecfg_reg_93 = 8'h0;
assign ecfg_reg_94 = {4'h0, vc_port_arb_sel[6], 1'b0};
assign ecfg_reg_95 = {vc_enable[6], 4'h0, vc_id[6]};
assign ecfg_reg_96 = 8'b0;                                              // RsvdP
assign ecfg_reg_97 = 8'b0;                                              // RsvdP
assign ecfg_reg_98 = {6'b0, vc_neg_pending[6], 1'b0};
assign ecfg_reg_99 = 8'b0;
// VC7
assign ecfg_reg_100 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC7 : 8'b0;
assign ecfg_reg_101 = {`DEFAULT_REJECT_NO_SNOOP_VC7,                    // When set, transaction without no-snoop is UR
                       `DEFAULT_AS_ONLY_VC7,                            // When set, only support AS packet traffic
                       6'b0};                                           // RsvdP
assign ecfg_reg_102 = {1'b0,                                            // RsvdP
                       `DEFAULT_MAX_TIME_SLOTS_VC7};                    // Maximum Time Slot
assign ecfg_reg_103 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC7 : 8'b0;
assign ecfg_reg_104 = {tc_vc_map[7], 1'b0};
assign ecfg_reg_105 = 8'h0;
assign ecfg_reg_106 = {4'h0, vc_port_arb_sel[7], 1'b0};
assign ecfg_reg_107 = {vc_enable[7], 4'h0, vc_id[7]};
assign ecfg_reg_108 = 8'b0;                                             // RsvdP
assign ecfg_reg_109 = 8'b0;                                             // RsvdP
assign ecfg_reg_110 = {6'b0, vc_neg_pending[7], 1'b0};
assign ecfg_reg_111 = 8'b0;




// General VC Assignments

// VC Structure enables
assign cfg_vc_enable = vc_enable[NVC-1:0];

// VC Structure to VC ID mapping
wire [23:0] tmp_vc_struc_vc_id_map;
assign tmp_vc_struc_vc_id_map   = VC_EN ?
                                       {vc_id[7], vc_id[6], vc_id[5], vc_id[4], vc_id[3], vc_id[2], vc_id[1], 3'h0}
                                       : 24'b0;

assign cfg_vc_struc_vc_id_map = tmp_vc_struc_vc_id_map[(NVC*3)-1:0];

// VC ID to VC Structure mapping
reg  [2:0]  tmp_vc_id_vc_struc_map[7:1];



// LMD: Variable in the sensitivity list but not used in the block
// LJ: vc_id and tc_vc_map arrays are always defined but only the first NVC are used, hence the warning. Using always@(*) wouldn't work on Xilinx tools
// leda W456 off
// LMD: Missing or redundant signals in the sensitivity list of a combinational block. Signal <item> is missing or redundant.
// LJ: vc_id and tc_vc_map arrays are always defined but only the first NVC are used, hence the warning. Using always@(*) wouldn't work on Xilinx tools
// leda C_2C_R off
always @(vc_id[1] or vc_id[2] or vc_id[3] or vc_id[4] or vc_id[5] or vc_id[6] or vc_id[7])
begin : vc_id_struc_map_update
    integer i, j;

    for (j=1; j<8; j=j+1) begin
        tmp_vc_id_vc_struc_map[j] = 3'h0;
        for (i=1; i<NVC; i=i+1) begin
            if (vc_id[i] == j)
                tmp_vc_id_vc_struc_map[j] = i;
        end
    end
end
// leda C_2C_R on
// leda W456 on



assign cfg_vc_id_vc_struc_map = VC_EN ?
                                {tmp_vc_id_vc_struc_map[7], tmp_vc_id_vc_struc_map[6], tmp_vc_id_vc_struc_map[5], tmp_vc_id_vc_struc_map[4],
                                 tmp_vc_id_vc_struc_map[3], tmp_vc_id_vc_struc_map[2], tmp_vc_id_vc_struc_map[1], 3'h0}
                                : 24'h0;

// Traffic Class to VC Structure mapping
wire    [7:0]   tc_vc1_map;
assign tc_vc1_map = {tc_vc_map[1], 1'b0};
wire    [7:0]   tc_vc2_map;
assign tc_vc2_map = {tc_vc_map[2], 1'b0};
wire    [7:0]   tc_vc3_map;
assign tc_vc3_map = {tc_vc_map[3], 1'b0};
wire    [7:0]   tc_vc4_map;
assign tc_vc4_map = {tc_vc_map[4], 1'b0};
wire    [7:0]   tc_vc5_map;
assign tc_vc5_map = {tc_vc_map[5], 1'b0};
wire    [7:0]   tc_vc6_map;
assign tc_vc6_map = {tc_vc_map[6], 1'b0};
wire    [7:0]   tc_vc7_map;
assign tc_vc7_map = {tc_vc_map[7], 1'b0};

reg     [2:0]   tmp_tc_vc_map[7:0];

always @(tc_vc0_map or tc_vc1_map or tc_vc2_map or tc_vc3_map or tc_vc4_map or tc_vc5_map or tc_vc6_map or tc_vc7_map)
begin : tc_vc_map_update
    integer i;

    for (i=0; i<8; i=i+1) begin
        if (tc_vc0_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h0;

        else if (tc_vc1_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h1;
        else if (tc_vc2_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h2;
        else if (tc_vc3_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h3;
        else if (tc_vc4_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h4;
        else if (tc_vc5_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h5;
        else if (tc_vc6_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h6;
        else if (tc_vc7_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h7;

        else
            tmp_tc_vc_map[i] = 3'h0;
    end
end

assign cfg_tc_vc_struc_map = VC_EN ?
                             {tmp_tc_vc_map[7], tmp_tc_vc_map[6], tmp_tc_vc_map[5], tmp_tc_vc_map[4],
                              tmp_tc_vc_map[3], tmp_tc_vc_map[2], tmp_tc_vc_map[1], 3'h0}
                             : 24'h0;

// Traffic Class to VC ID mapping
integer m,n;
reg [7:0]   local_tc_vc_map;
reg [2:0]   tmp2_tc_vc_map[7:0];

// LMD: Variable in the sensitivity list but not used in the block
// LJ: vc_id and tc_vc_map arrays are always defined but only the first NVC are used, hence the warning
// leda W456 off
// LMD: Missing or redundant signals in the sensitivity list of a combinational block. Signal <item> is missing or redundant.
// LJ: vc_id and tc_vc_map arrays are always defined but only the first NVC are used, hence the warning
// leda C_2C_R off
always @(tc_vc_map[0] or tc_vc_map[1] or tc_vc_map[2] or tc_vc_map[3] or tc_vc_map[4] or
         tc_vc_map[5] or tc_vc_map[6] or tc_vc_map[7] or vc_id[1] or
         vc_id[2] or vc_id[3] or vc_id[4] or vc_id[5] or vc_id[6] or vc_id[7])
begin : tc_vc_map_update2
    tmp2_tc_vc_map[0] = 0;
    for (m=1; m<8; m=m+1) begin
        tmp2_tc_vc_map[m] = 0;
        for (n=0; n<NVC; n=n+1) begin
            local_tc_vc_map = {tc_vc_map[n],1'b0};
            if (local_tc_vc_map[m]) begin
                if (n==0)
                    tmp2_tc_vc_map[m] = 3'b0;
                else
                    tmp2_tc_vc_map[m] = vc_id[n];
            end
        end
    end
end
// leda W456 on
// leda C_2C_R on

assign cfg_tc_vc_map = VC_EN ?
                       {tmp2_tc_vc_map[7], tmp2_tc_vc_map[6], tmp2_tc_vc_map[5], tmp2_tc_vc_map[4],
                        tmp2_tc_vc_map[3], tmp2_tc_vc_map[2], tmp2_tc_vc_map[1], 3'h0}
                       : 24'h0;

// Traffic Class enable
assign cfg_tc_enable = VC_EN ?
                       tc_vc0_map | tc_vc1_map | tc_vc2_map | tc_vc3_map  | tc_vc4_map  | tc_vc5_map  | tc_vc6_map | tc_vc7_map
                       : 8'hFF;

generate
//gen_dsn_hdr_reg is used to generate the DSN header register only. 
//(1) If CX_DSN_PF0_ONLY_EN is defined:
// - Header regitser is implemented for PF0 and PF1 only. 
// - Header register of PFs>1 will shadow PF1 header register using cfg_dsn_reg_pf0_pf1 input signal. 
//(2) If CX_DSN_PF0_ONLY_EN is not defined:
// - Header regitser is implemented for all PFs.

if( (DSN_NF < NF) && (FUNC_NUM == 0 || FUNC_NUM == 1) || (DSN_NF == NF) && (FUNC_NUM < DSN_NF) ) begin : gen_dsn_hdr_reg
// =============================================================================
// Device Serial Number Capability Structure
// =============================================================================
// Serial CAP register
// sn_reg_id        - 0
// PCIE Offset      - `SN_PTR
// Length           - 4 bytes
// Default value    - {`SN_NEXT_PTR, 4'h1, 16'h3}
// Cfig register    - sn_reg_03, sn_reg_02, sn_reg_01, sn_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_sn_id;          // DSN Capability ID
reg [3:0]   cfg_sn_ver;         // DSN Capability Version
reg [11:0]  cfg_sn_next_ptr;    // DSN Next Capability Offset
reg         sn_next_ptr_wr_updated;    // Asserted when DSN Capability header has been changed by a DBI write

// Capabilities such as RBAR should not
// be visible to a DM product in Root Port mode; hence, when rc_device
// is true then the next pointer is in a smaller linked list.

assign {sn_reg_01, sn_reg_00}       = cfg_sn_id;
assign sn_reg_02[3:0]               = cfg_sn_ver;
assign {sn_reg_03, sn_reg_02[7:4]}  = cfg_sn_next_ptr;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : sn_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_sn_id[15:0]       <= #TP 16'h3;                // Device Serial Num Cap ID
        cfg_sn_ver[3:0]       <= #TP 4'h1;                 // Capability version
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_sn_id[7:0]        <= #TP (sn_reg_id[0] & write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_sn_id[7:0];
        cfg_sn_id[15:8]       <= #TP (sn_reg_id[0] & write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_sn_id[15:8];
        cfg_sn_ver[3:0]       <= #TP (sn_reg_id[0] & write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_sn_ver[3:0];
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : sn_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_sn_next_ptr[11:0] <= #TP ((FUNC_NUM==0) ? `SN_NEXT_PTR_0 : `SN_NEXT_PTR_N);                       // Assume EP linked list at reset.
    end else if (sn_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_sn_next_ptr[3:0]  <= #TP write_pulse[2] ? lbc_cdm_data[23:20] : cfg_sn_next_ptr[3:0];
        cfg_sn_next_ptr[11:4] <= #TP write_pulse[3] ? lbc_cdm_data[31:24] : cfg_sn_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !sn_next_ptr_wr_updated) begin
        cfg_sn_next_ptr[11:0]  <= #TP `DM_RP_SN_NEXT_PTR ;       // If RP or downstream port of SW, then use smaller linked list.
    end else if (!sn_next_ptr_wr_updated) begin
        cfg_sn_next_ptr[11:0]  <= #TP (cxl_rcrb_enable && upstream_port) ? |RCRB ? `RCRB_SN_NEXT_PTR : `CXL_SN_NEXT_PTR : ((FUNC_NUM==0) ?  `SN_NEXT_PTR_0 :  `SN_NEXT_PTR_N) ;             // Device type could change if crosslink enable is true.
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : sn_cap_hdr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        sn_next_ptr_wr_updated <= #TP 1'b0;
    end else if (sn_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |write_pulse[3:2]) begin
        sn_next_ptr_wr_updated <= #TP 1'b1;
    end
end


end

//gen_dsn_reg is used to generate the DSN upper/lower serial number registers only. 
//(1) If CX_DSN_PF0_ONLY_EN is defined:
// - Upper/lower serial number registers are implemented for PF0 only. 
// - Upper/lower serial number registers of PFs>0 will shadow PF0 Upper/lower serial number registers using cfg_dsn_reg_pf0_pf1 input signal. 
//(2) If CX_DSN_PF0_ONLY_EN is not defined:
// - Upper/lower serial number registers are implemented for all PFs.

if( FUNC_NUM < DSN_NF ) begin : gen_dsn_reg
// -----------------------------------------------------------------------------
// Serial Number register (DW1)
// sn_reg_id        - 1
// PCIE Offset      - `SN_PTR + 04h
// Length           - 4 bytes
// Default value    - `DEFAULT_SN_DW1
// Cfig register    - sn_reg_07, sn_reg_06, sn_reg_05, sn_reg_04
// -----------------------------------------------------------------------------
reg     [31:0]  cfg_sn_dw1;

assign {sn_reg_07, sn_reg_06, sn_reg_05, sn_reg_04} = cfg_sn_dw1;

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_sn_dw1        <= #TP `DEFAULT_SN_DW1;
    end else begin
        if (SN_EN) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            cfg_sn_dw1[7:0]     <= #TP (write_pulse[0] & sn_reg_id[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0]   : cfg_sn_dw1[7:0];
            cfg_sn_dw1[15:8]    <= #TP (write_pulse[1] & sn_reg_id[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8]  : cfg_sn_dw1[15:8];
            cfg_sn_dw1[23:16]   <= #TP (write_pulse[2] & sn_reg_id[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_sn_dw1[23:16];
            cfg_sn_dw1[31:24]   <= #TP (write_pulse[3] & sn_reg_id[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_sn_dw1[31:24];
        end
        else begin
            cfg_sn_dw1          <= #TP `DEFAULT_SN_DW1;
        end
    end
end

// -----------------------------------------------------------------------------
// Serial Number register (DW2)
// sn_reg_id        - 2
// PCIE Offset      - `SN_PTR + 08h
// Length           - 4 bytes
// Default value    - `DEFAULT_SN_DW2
// Cfig register    - sn_reg_11, sn_reg_10, sn_reg_09, sn_reg_08
// -----------------------------------------------------------------------------
reg     [31:0]  cfg_sn_dw2;

assign {sn_reg_11, sn_reg_10, sn_reg_09, sn_reg_08} = cfg_sn_dw2;

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_sn_dw2        <= #TP `DEFAULT_SN_DW2;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        if (SN_EN) begin
            cfg_sn_dw2[7:0]     <= #TP (write_pulse[0] & sn_reg_id[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0]   : cfg_sn_dw2[7:0];
            cfg_sn_dw2[15:8]    <= #TP (write_pulse[1] & sn_reg_id[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8]  : cfg_sn_dw2[15:8];
            cfg_sn_dw2[23:16]   <= #TP (write_pulse[2] & sn_reg_id[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_sn_dw2[23:16];
            cfg_sn_dw2[31:24]   <= #TP (write_pulse[3] & sn_reg_id[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_sn_dw2[31:24];
        end
        else begin
            cfg_sn_dw2          <= #TP `DEFAULT_SN_DW2;
        end
    end
end


end 
endgenerate 


generate
if(FUNC_NUM < PB_NF ) begin : gen_pb_reg
// =============================================================================
// Power Budgeting Capability Structure
// =============================================================================
// Power Budget CAP register
// pb_reg_id        - 0
// PCIE Offset      - `PB_PTR
// Length           - 4 bytes
// Default value    - {`PB_NEXT_PTR, 4'h1, 16'h4}
// Cfig register    - pb_reg_03, pb_reg_02, pb_reg_01, pb_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_pb_id;          // PB Capability ID
reg [3:0]   cfg_pb_ver;         // PB Capability Version
reg [11:0]  cfg_pb_next_ptr;    // PB Next Capability Offset
reg         pb_next_ptr_wr_updated;    // Asserted when PB Capability header has been changed by a DBI write

// Capabilities such as RBAR should not
// be visible to a DM product in Root Port mode; hence, when rc_device
// is true then the next pointer is in a smaller linked list.

assign {pb_reg_01, pb_reg_00}       = cfg_pb_id;
assign pb_reg_02[3:0]               = cfg_pb_ver;
assign {pb_reg_03, pb_reg_02[7:4]}  = cfg_pb_next_ptr;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : pb_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_pb_id[15:0]       <= #TP 16'h4;                // PB Cap ID
        cfg_pb_ver[3:0]       <= #TP 4'h1;                 // Capability version
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_pb_id[7:0]        <= #TP (pb_reg_id[0] & write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_pb_id[7:0];
        cfg_pb_id[15:8]       <= #TP (pb_reg_id[0] & write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_pb_id[15:8];
        cfg_pb_ver[3:0]       <= #TP (pb_reg_id[0] & write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_pb_ver[3:0];
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : pb_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_pb_next_ptr[11:0] <= #TP ((FUNC_NUM==0) ? `PB_NEXT_PTR_0  : `PB_NEXT_PTR_N);       // Assume EP linked list at reset.
    end else if (pb_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_pb_next_ptr[3:0]  <= #TP write_pulse[2] ? lbc_cdm_data[23:20] : cfg_pb_next_ptr[3:0];
        cfg_pb_next_ptr[11:4] <= #TP write_pulse[3] ? lbc_cdm_data[31:24] : cfg_pb_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !pb_next_ptr_wr_updated) begin
        cfg_pb_next_ptr[11:0] <= #TP `DM_RP_PB_NEXT_PTR ; // If RP or downstream port of SW, then use smaller linked list.
    end else if (!pb_next_ptr_wr_updated) begin
        cfg_pb_next_ptr[11:0] <= #TP (cxl_rcrb_enable && upstream_port) ? |RCRB ? 'b0 : `CXL_PB_NEXT_PTR : ((FUNC_NUM==0) ?  `PB_NEXT_PTR_0  :  `PB_NEXT_PTR_N) ;       // If RP or upstream port of SW, then use full linked list. Device type could change if crosslink enable is true.
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : pb_cap_hdr_wr_updated_PROC
    if ( !sticky_rst_n ) begin
        pb_next_ptr_wr_updated <= #TP 1'b0;
    end else if (pb_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |write_pulse[3:2]) begin
        pb_next_ptr_wr_updated <= #TP 1'b1;
    end
end


// -----------------------------------------------------------------------------
// Data Select Register, Power Budgeting Control Register
// pb_reg_id        - 1
// PCIE Offset      - `PB_PTR + 04h
// Length           - 4 bytes
// Default value    - 0
// Cfig register    - pb_reg_07, pb_reg_06, pb_reg_05, pb_reg_04
// -----------------------------------------------------------------------------

assign {pb_reg_07, pb_reg_06, pb_reg_05}    = 24'h0;        // RsvdP

assign pb_reg_04                            = cfg_pwr_budget_data_sel_reg;



always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_pwr_budget_data_sel_reg <= #TP 0;
        cfg_pwr_budget_sel          <= #TP 0;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        if (PB_EN) begin
            cfg_pwr_budget_data_sel_reg <= #TP (write_pulse[0] & pb_reg_id[1]) ? lbc_cdm_data[7:0]   : cfg_pwr_budget_data_sel_reg;
            cfg_pwr_budget_sel          <= #TP (write_pulse[0] & pb_reg_id[1]);
        end
        else begin
            cfg_pwr_budget_data_sel_reg <= #TP 0;
            cfg_pwr_budget_sel          <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// Data Register
// pb_reg_id        - 2
// PCIE Offset      - `PB_PTR + 08h
// Length           - 4 bytes
// Default value    - 0
// Cfig register    - pb_reg_11, pb_reg_10, pb_reg_09, pb_reg_08
// -----------------------------------------------------------------------------
reg     [31:0]  clked_cfg_pwr_budget_data_reg;
assign {pb_reg_11, pb_reg_10, pb_reg_09, pb_reg_08} = clked_cfg_pwr_budget_data_reg;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        clked_cfg_pwr_budget_data_reg   <= #TP 0;
    end
    else begin
        if (PB_EN)begin

            clked_cfg_pwr_budget_data_reg   <= #TP (cfg_pwr_budget_func_num == FUNC_NUM) ? cfg_pwr_budget_data_reg : clked_cfg_pwr_budget_data_reg;
        end
        else
            clked_cfg_pwr_budget_data_reg   <= #TP 0;
    end
end


// -----------------------------------------------------------------------------
// Power Budgeting Capability Register, Power Budgeting Sense Detect Register
// pb_reg_id        - 3
// PCIE Offset      - `PB_PTR + 0Ch
// Length           - 4 bytes
// Default value    - HWInit
// Cfig register    - pb_reg_15, pb_reg_14, pb_reg_13, pb_reg_12
// -----------------------------------------------------------------------------
reg             cfg_pwr_budget_sys_alloc;



assign {pb_reg_15, pb_reg_14, pb_reg_13}    = 24'h0;                            // RsvdP
assign pb_reg_12                            = {
                                                7'h0, 
                                                cfg_pwr_budget_sys_alloc
                                              };

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_pwr_budget_sys_alloc    <= #TP `DEFAULT_PWR_BUDGET_SYS_ALLOC;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        if (PB_EN) begin
            cfg_pwr_budget_sys_alloc    <= #TP (write_pulse[0] & pb_reg_id[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[0] : cfg_pwr_budget_sys_alloc;
        end
        else begin
            cfg_pwr_budget_sys_alloc    <= #TP 0;
        end
    end
end


end else begin : gen_pb_reg 
  assign {pb_reg_03, pb_reg_02, pb_reg_01, pb_reg_00} = 32'b0;
  assign {pb_reg_07, pb_reg_06, pb_reg_05, pb_reg_04} = 32'b0;
  assign {pb_reg_11, pb_reg_10, pb_reg_09, pb_reg_08} = 32'b0;
  assign {pb_reg_15, pb_reg_14, pb_reg_13, pb_reg_12} = 32'b0;
  assign cfg_pwr_budget_data_sel_reg                  = 8'b0;
  assign cfg_pwr_budget_sel                           = 1'b0; 
end // gen_pb_reg
endgenerate 




// -----------------------------------------------------------------------------
// IDE Extended Capability registers
// used for passthrough feature only
// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
// TPH Capability registers
// -----------------------------------------------------------------------------

cdm_tph_reg
 #(.INST(INST), .FUNC_NUM(FUNC_NUM), .VF_IMPL(0)
, .RCRB(RCRB)
)
u_cdm_tph_reg (
               // INPUTS
               .core_clk                 (core_clk),
               .non_sticky_rst_n         (non_sticky_rst_n),
               .sticky_rst_n             (sticky_rst_n),
               .cdm_clk_g                (cdm_clk_g),
               .lbc_cdm_data             (lbc_cdm_data),
               .lbc_cdm_dbi              (lbc_cdm_dbi),
               .lbc_cdm_dbi2             (lbc_cdm_dbi2),
               .tph_write_pulse          (write_pulse),
               .tph_read_pulse           (read_pulse),
               .tph_reg_id               (tph_reg_id),
               .dbi_ro_wr_en             (dbi_ro_wr_en),
               .device_type              (device_type),
               .cxl_rcrb_enable          (cxl_rcrb_enable),

               // OUTPUTS
               .cfg_tph_req_en           (cfg_tph_req_en),
               .cfg_tph_st_mode          (cfg_pf_tph_st_mode),

               .tph_reg_data             (tph_reg_data)
             );

cdm_ats_reg
 #(.INST(INST), .FUNC_NUM(FUNC_NUM), .VF_IMPL(0)
, .RCRB(RCRB)
)
u_cdm_ats_reg (
               // INPUTS
               .core_clk                 (core_clk),
               .non_sticky_rst_n         (non_sticky_rst_n),
               .sticky_rst_n             (sticky_rst_n),
               .cdm_clk_g                (cdm_clk_g),
               .lbc_cdm_data             (lbc_cdm_data),
               .lbc_cdm_dbi              (lbc_cdm_dbi),
               .ats_write_pulse          (write_pulse),
               .ats_read_pulse           (read_pulse),
               .ats_reg_id               (ats_reg_id),
               .dbi_ro_wr_en             (dbi_ro_wr_en),
               .cxl_rcrb_enable          (cxl_rcrb_enable),

               // OUTPUTS
               .cfg_ats_stu              (cfg_ats_stu),
               .cfg_ats_cache_en         (cfg_ats_cache_en),
               .ats_reg_data             (ats_reg_data)
             );


cdm_prs_reg
 #(.INST(INST), .FUNC_NUM(FUNC_NUM)
)
u_cdm_prs_reg (
               // INPUTS
               .core_clk                 (core_clk),
               .non_sticky_rst_n         (non_sticky_rst_n),
               .sticky_rst_n             (sticky_rst_n),
               .cdm_clk_g                (cdm_clk_g),
               .lbc_cdm_data             (lbc_cdm_data),
               .lbc_cdm_dbi              (lbc_cdm_dbi),
               .prs_write_pulse          (write_pulse),
               .prs_reg_id               (prs_reg_id),
               .dbi_ro_wr_en             (dbi_ro_wr_en),
               .prs_res_failure          (prs_res_failure),
               .prs_uprgi                (prs_uprgi),
               .prs_stopped              (prs_stopped),
               .cxl_rcrb_enable          (cxl_rcrb_enable),

               // OUTPUTS
               .prs_reg_data                    (prs_reg_data),
               .cfg_prs_enable                  (cfg_prs_enable),
               .cfg_prs_reset                   (cfg_prs_reset),
               .cfg_prs_stopped                 (cfg_prs_stopped),
               .cfg_prs_uprgi                   (cfg_prs_uprgi),
               .cfg_prs_response_failure        (cfg_prs_response_failure),
               .cfg_prs_outstanding_allocation  (cfg_prs_outstanding_allocation)
             );

generate
if(FUNC_NUM==0) begin : gen_cdm_ltr_reg
cdm_ltr_reg
  #(.INST(INST),
               .FUNC_NUM(FUNC_NUM)
           )
u_cdm_ltr_reg (
               // INPUTS
               .core_clk                 (core_clk),
               .non_sticky_rst_n         (non_sticky_rst_n),
               .sticky_rst_n             (sticky_rst_n),
               .cdm_clk_g                (cdm_clk_g),
               .lbc_cdm_data             (lbc_cdm_data),
               .lbc_cdm_dbi              (lbc_cdm_dbi),
               .write_pulse              (write_pulse),
               .read_pulse               (read_pulse),
               .ltr_reg_id               (ltr_reg_id),
               .cx_dbi_ro_wr_en          (dbi_ro_wr_en),
               .cxl_rcrb_enable          (cxl_rcrb_enable),
               // OUTPUTS
               .cfg_ltr_max_latency      (cfg_ltr_max_latency),
               .ltr_reg_data             (ltr_reg_data)
             );

end else begin : gen_cdm_ltr_reg
  assign cfg_ltr_max_latency = 'b0;
  assign ltr_reg_data = 'b0;
end // gen_cdm_ltr_reg
endgenerate


   generate
     if (NUM_RBARS > 0) begin : gen_cdm_rbar_reg
       cdm_rbar_reg
         #(.INST(INST),
                       .FUNC_NUM(FUNC_NUM),
                       .VF_BAR(0)
                      )
       u_cdm_rbar_reg (
                      // INPUTS
                      .core_clk             (core_clk),
                      .sticky_rst_n         (sticky_rst_n),
                      .non_sticky_rst_n     (non_sticky_rst_n),
                      .lbc_cdm_data         (lbc_cdm_data),
                      .lbc_cdm_dbi          (lbc_cdm_dbi),
                      .lbc_cdm_dbi2         (lbc_cdm_dbi2),
                      .write_pulse          (write_pulse),
                      .rbar_reg_id          (rbar_reg_id),
                      .cx_dbi_ro_wr_en          (dbi_ro_wr_en),
                      .cxl_rcrb_enable          (cxl_rcrb_enable),
                      // OUTPUTS
                      .rbar_reg_data        (rbar_reg_data),
                      .rbar_bar_resizable   (cfg_rbar_bar_resizable),
                      .rbar_bar0_mask       (cfg_rbar_bar0_mask),
                      .rbar_bar1_mask       (cfg_rbar_bar1_mask),
                      .rbar_bar2_mask       (cfg_rbar_bar2_mask),
                      .rbar_bar3_mask       (cfg_rbar_bar3_mask),
                      .rbar_bar4_mask       (cfg_rbar_bar4_mask),
                      .rbar_bar5_mask       (cfg_rbar_bar5_mask),
                       .rbar_ctrl_update     (rbar_ctrl_update),
                      .cfg_rbar_size        (cfg_rbar_size)
                    );
      end else begin : gen_cdm_no_rbar_reg
         assign rbar_reg_data = 0;
         assign cfg_rbar_bar_resizable = 0;
         assign cfg_rbar_bar0_mask = 0;
         assign cfg_rbar_bar1_mask = 0;
         assign cfg_rbar_bar2_mask = 0;
         assign cfg_rbar_bar3_mask = 0;
         assign cfg_rbar_bar4_mask = 0;
         assign cfg_rbar_bar5_mask = 0;
         assign rbar_ctrl_update   = 0;
         assign cfg_rbar_size      = 0;
      end
   endgenerate

generate
     if (NUM_VF_RBARS > 0) begin : gen_cdm_vf_rbar_reg
       cdm_rbar_reg
         #(.INST(INST),
                       .FUNC_NUM(FUNC_NUM),
                       .VF_BAR(NUM_VF_RBARS)
                      )
       u_cdm_vf_rbar_reg (
                      // INPUTS
                      .core_clk             (core_clk),
                      .sticky_rst_n         (sticky_rst_n),
                      .non_sticky_rst_n     (non_sticky_rst_n),
                      .lbc_cdm_data         (lbc_cdm_data),
                      .lbc_cdm_dbi          (lbc_cdm_dbi),
                      .lbc_cdm_dbi2         (lbc_cdm_dbi2),
                      .write_pulse          (write_pulse),
                      .rbar_reg_id          (vf_rbar_reg_id),
                      .cx_dbi_ro_wr_en      (dbi_ro_wr_en),
                      .cxl_rcrb_enable      (cxl_rcrb_enable),
                      // OUTPUTS
                      .rbar_reg_data        (vf_rbar_reg_data),
                      .rbar_bar_resizable   (cfg_vf_rbar_bar_resizable),
                      .rbar_bar0_mask       (cfg_vf_rbar_bar0_mask),
                      .rbar_bar1_mask       (cfg_vf_rbar_bar1_mask),
                      .rbar_bar2_mask       (cfg_vf_rbar_bar2_mask),
                      .rbar_bar3_mask       (cfg_vf_rbar_bar3_mask),
                      .rbar_bar4_mask       (cfg_vf_rbar_bar4_mask),
                      .rbar_bar5_mask       (cfg_vf_rbar_bar5_mask),
                       .rbar_ctrl_update     (vf_rbar_ctrl_update),
                      .cfg_rbar_size        (cfg_vf_rbar_size)
                    );
      end else begin : gen_cdm_no_vf_rbar_reg
         assign vf_rbar_reg_data = 0;
         assign cfg_vf_rbar_bar_resizable = 0;
         assign cfg_vf_rbar_bar0_mask = 0;
         assign cfg_vf_rbar_bar1_mask = 0;
         assign cfg_vf_rbar_bar2_mask = 0;
         assign cfg_vf_rbar_bar3_mask = 0;
         assign cfg_vf_rbar_bar4_mask = 0;
         assign cfg_vf_rbar_bar5_mask = 0;
         assign vf_rbar_ctrl_update   = 0;
         assign cfg_vf_rbar_size      = 0;
      end
   endgenerate


// ---------- PF PASID Capabilities ----------------------------------------

cdm_pasid_reg
  #(.INST(INST),
               .FUNC_NUM(FUNC_NUM),
               .VF_IMPL(0)
           )
u_cdm_pasid_reg (
               // INPUTS
               .core_clk                 (core_clk),
               .non_sticky_rst_n         (non_sticky_rst_n),
               .sticky_rst_n             (sticky_rst_n),
               .cdm_clk_g                (cdm_clk_g),
               .lbc_cdm_data             (lbc_cdm_data),
               .lbc_cdm_dbi              (lbc_cdm_dbi),
               .pasid_write_pulse        (write_pulse),
               .pasid_reg_id             (pasid_reg_id),
               .dbi_ro_wr_en             (dbi_ro_wr_en),
               .cxl_rcrb_enable          (cxl_rcrb_enable),
               // OUTPUTS
               .cfg_pasid_control        (cfg_pf_pasid_control),
               .pasid_reg_data           (pasid_reg_data)
             );




// ---------- RTR Capabilities ---------------------------

cdm_rtr_reg
  #(.INST(INST),
               .FUNC_NUM(FUNC_NUM),
               .NRTR(NRTR),
                .VF_IMPL (0) )          //0 for physical function
u_cdm_rtr_reg (
               // INPUTS
               .core_clk                 (core_clk),
               .cdm_clk_g                (cdm_clk_g),
               .sticky_rst_n             (sticky_rst_n),
               .device_type              (device_type),

               .lbc_cdm_data             (lbc_cdm_data),
               .lbc_cdm_dbi              (lbc_cdm_dbi),
               .lbc_cdm_dbi2             (lbc_cdm_dbi2),
               .rtr_write_pulse          (write_pulse),
               //.rtr_read_pulse            (read_pulse),
               .rtr_reg_id               (rtr_reg_id),
               .dbi_ro_wr_en             (dbi_ro_wr_en),
               .cxl_rcrb_enable          (cxl_rcrb_enable),

               // OUTPUTS
               .rtr_reg_data             (rtr_reg_data)
             );





// ---------- FRSQ Capabilities ---------------------------
generate
  if(FUNC_NUM==0) begin : frsq_gen          //generate is to enable Leda pass when DM

cdm_frsq_reg
  #(.INST(INST),
               .FUNC_NUM(FUNC_NUM),
               .NFRSQ(NFRSQ)
             )

u_cdm_frsq_reg (
               // INPUTS
               .core_clk                  (core_clk),
               .non_sticky_rst_n          (non_sticky_rst_n),
               .sticky_rst_n              (sticky_rst_n),
               .cdm_clk_g                 (cdm_clk_g),

               .lbc_cdm_data              (lbc_cdm_data),
               .lbc_cdm_dbi               (lbc_cdm_dbi),
               .frsq_write_pulse          (write_pulse),
               .frsq_reg_id               (frsq_reg_id),
               .dbi_ro_wr_en              (dbi_ro_wr_en),

               .cfg_downstream_comp_pres (cfg_downstream_comp_pres),      //should be 3 bits of new downstream component prescence
               .radm_frs_msg_reason      (radm_frs_msg_reason),
               .radm_msg_req_id          (radm_msg_req_id),
               .radm_frs_msg             (radm_frs_msg),         //signal is a pulse from radm
               .radm_drs_msg             (radm_drs_msg),
               .pmstate_d3hot_to_d0      (pmstate_d3hot_to_d0),
               .cfg_pbus_num             (cfg_pbus_num),
               .cfg_pbus_dev_num         (cfg_pbus_dev_num),
               .cfg_drs_frs_sig_en       (cfg_drs_frs_sig_en),
               .cfg_msi_en               (cfg_msi_en),
               .cfg_msix_en              (cfg_msix_en),
               .upstream_port            (upstream_port),
               .rdlh_link_up             (rdlh_link_up),

              // OUTPUTS
               .frsq_msi                 (frsq_msi),                         // MSI or MSI-X pulse
               .frsq_int_msg_num         (frsq_int_msg_num),                 // FRSQ Interrupt vector
               .frsq_reg_data            (frsq_reg_data)
             );

  end else begin : frsq_gen         // so DM can read the Capability info correctly

    assign frsq_msi=1'b0;
    assign frsq_int_msg_num=5'b0;
    assign frsq_reg_data={`DM_RP_FRSQ_NEXT_PTR, `PCIE_FRSQ_ECAP_VER, `PCIE_FRSQ_ECAP_ID};
  end
endgenerate // frsq_gen


localparam DLINK_PTR = `DLINK_PTR;
wire [22:0] cfg_local_feature_support;
wire [22:0] cfg_remote_feature_support;
wire        cfg_dlink_feature_valid;
wire        fc_scaled_en;
always @(posedge cdm_clk_g or negedge non_sticky_rst_n) begin : dlink_reg_id_proc

integer depth;

  if(!non_sticky_rst_n)
    dlink_reg_id <= #TP 0;
  else if ((|RCRB) ^ cxl_rcrb_enable)
    dlink_reg_id <= #TP 0;
  else
    for (depth = 0; depth < NDLINK; depth = depth + 1)
    begin : gen_DLINK_REG_ID
      dlink_reg_id[depth] <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( DLINK_PTR + (depth*4)) >> 2)) & ecfg_reg_sel) : dlink_reg_id[depth];
    end
end // dlink_reg_id_proc


generate
  if(FUNC_NUM==0) begin : dlink_gen
    cdm_dlink_reg
     #(.INST(INST),
      .FUNC_NUM(FUNC_NUM),
      .NDLINK(NDLINK)
, .RCRB(RCRB)
    )
    u_cdm_dlink_reg (
      // Inputs
      .core_clk                   (core_clk),
      .sticky_rst_n               (sticky_rst_n),
      .cdm_clk_g                  (cdm_clk_g),
      .non_sticky_rst_n           (non_sticky_rst_n),
      .device_type                (device_type),
      .lbc_cdm_data               (lbc_cdm_data),
      .lbc_cdm_dbi                (lbc_cdm_dbi),
      .lbc_cdm_dbi2               (lbc_cdm_dbi2),
      .dbi_ro_wr_en               (dbi_ro_wr_en),
      .dlink_write_pulse          (write_pulse),
      .dlink_reg_id               (dlink_reg_id),

      .rdlh_rcvd_dl_feature       (rdlh_rcvd_dl_feature),
      .rcvd_dl_feature_content    (rcvd_dl_feature_content),
      .rdlh_dlcntrl_state         (rdlh_dlcntrl_state),     // input [1:0]
      .cxl_rcrb_enable            (cxl_rcrb_enable),
      .cfg_pcie_cap_flit_mode_sup (cfg_pcie_cap_flit_mode_sup),
      // Outputs
      .dlink_reg_data             (dlink_reg_data),
      .cfg_local_feature_support  (cfg_local_feature_support),
      .cfg_remote_feature_support (cfg_remote_feature_support),
      .cfg_dlink_feature_valid    (cfg_dlink_feature_valid),
      .dl_feature_en              (dl_feature_en),
      .cfg_remote_feature_ack     (cfg_remote_feature_ack),
      .fc_scaled_en               (fc_scaled_en)
    );
    end else begin : dlink_gen
      // Outputs
    assign dlink_reg_data = 32'b0;
    assign cfg_local_feature_support = 23'b0;
    assign cfg_remote_feature_support = 23'b0;
    assign cfg_dlink_feature_valid = 1'b0;
    assign dl_feature_en = 1'b0;
    assign cfg_remote_feature_ack = 1'b0;
    assign fc_scaled_en = 1'b0;
  end
  endgenerate






cdm_acs_reg
 #(.INST(INST), .FUNC_NUM(FUNC_NUM)
, .RCRB(RCRB)
)
u_cdm_acs_reg (
               // INPUTS
               .core_clk                 (core_clk),
               .non_sticky_rst_n         (non_sticky_rst_n),
               .sticky_rst_n             (sticky_rst_n),
               .device_type              (device_type),
               .lbc_cdm_data             (lbc_cdm_data),
               .lbc_cdm_dbi              (lbc_cdm_dbi),
               .lbc_cdm_dbi2             (lbc_cdm_dbi2),
               .acs_write_pulse          (write_pulse),
               .acs_reg_id               (acs_reg_id),
               .dbi_ro_wr_en             (dbi_ro_wr_en),
               .upstream_port            (upstream_port),
               .pf_cfg_acs_p2p_req_redirect_cap         (1'b0),
               .pf_cfg_acs_p2p_compl_redirect_cap       (1'b0),
               .pf_cfg_acs_p2p_egress_ctrl_cap          (1'b0),
               .pf_cfg_acs_p2p_direct_transl_cap        (1'b0),
               .pf_cfg_acs_egress_ctrl_vector_size_cap  (8'b0),
               .cxl_rcrb_enable                      (cxl_rcrb_enable),

               // OUTPUTS
               .cfg_acs_validation_cap               (cfg_acs_validation_cap),
               .cfg_acs_at_blocking_cap              (cfg_acs_at_blocking_cap),
               .cfg_acs_up_forward_cap               (cfg_acs_up_forward_cap),
               .cfg_acs_p2p_req_redirect_cap         (cfg_acs_p2p_req_redirect_cap),
               .cfg_acs_p2p_compl_redirect_cap       (cfg_acs_p2p_compl_redirect_cap),
               .cfg_acs_p2p_egress_ctrl_cap          (cfg_acs_p2p_egress_ctrl_cap),
               .cfg_acs_p2p_direct_transl_cap        (cfg_acs_p2p_direct_transl_cap),
               .cfg_acs_egress_ctrl_vector_size_cap  (cfg_acs_egress_ctrl_vector_size_cap),
               .cfg_acs_validation_en                (cfg_acs_validation_en),
               .cfg_acs_at_blocking_en               (cfg_acs_at_blocking_en),
               .cfg_acs_p2p_req_redirect_en          (cfg_acs_p2p_req_redirect_en),
               .cfg_acs_p2p_compl_redirect_en        (cfg_acs_p2p_compl_redirect_en),
               .cfg_acs_up_forward_en                (cfg_acs_up_forward_en),
               .cfg_acs_p2p_egress_ctrl_en           (cfg_acs_p2p_egress_ctrl_en),
               .cfg_acs_p2p_direct_transl_en         (cfg_acs_p2p_direct_transl_en),
               .cfg_acs_egress_ctrl_vec              (cfg_acs_egress_ctrl_vec),
               .acs_reg_data                         (acs_reg_data),
               .acs_viol_svrity_mask_wr_en           (acs_viol_svrity_mask_wr_en)
             );


// ---------- DPC Capabilities ----------------------------------------

// Downstream Port Capability applies to downstream ports (RP or SW) only.
//
generate
if(FUNC_NUM==0) begin : gen_cdm_dpc_reg
cdm_dpc_reg
  #(.INST(INST),
               .FUNC_NUM(FUNC_NUM),
               .NDPC(NDPC),
               .DPC_PRFX_LOG_SIZE(DPC_PRFX_LOG_SIZE),
               .DPC_PRFX_LOG_WD(DPC_PRFX_LOG_WD)
, .RCRB(RCRB)
           )
u_cdm_dpc_reg (
               // INPUTS
               .core_clk                           (core_clk),
               .non_sticky_rst_n                   (non_sticky_rst_n),
               .sticky_rst_n                       (sticky_rst_n),
               .cdm_clk_g                          (cdm_clk_g),
               .lbc_cdm_data                       (lbc_cdm_data),
               .lbc_cdm_dbi                        (lbc_cdm_dbi),
               .lbc_cdm_dbi2                       (lbc_cdm_dbi2),
               .dpc_write_pulse                    (write_pulse),
               .dpc_reg_id                         (dpc_reg_id),
               .dbi_ro_wr_en                       (dbi_ro_wr_en),
               .int_dpc_triggered                  (int_dpc_triggered),
               .int_dpc_trig_reason                (int_dpc_trig_reason),
               .int_dpc_trig_reason_extn           (int_dpc_trig_reason_extn),
               .dpc_err_src_id                     (dpc_err_src_id),
               .cfg_int_disable                    (cfg_int_disable),
               .cfg_msi_en                         (cfg_msi_en),
               .cfg_msix_en                        (cfg_msix_en),

               // OUTPUTS
               .cfg_dpc_int_msg_num                (cfg_dpc_int_msg_num),
               .cfg_dpc_rp_ext_dpc                 (cfg_dpc_rp_ext_dpc),
               .cfg_dpc_poison_tlp_egr_blk_support (cfg_dpc_poison_tlp_egr_blk_support),
               .cfg_dpc_sw_trig_support            (cfg_dpc_sw_trig_support),
               .cfg_dpc_rp_pio_log_size            (cfg_dpc_rp_pio_log_size),
               .cfg_dpc_dl_active_err_cor_support  (cfg_dpc_dl_active_err_cor_support),
               .cfg_dpc_trig_en                    (cfg_dpc_trig_en),
               .cfg_dpc_cpl_cntrl                  (cfg_dpc_cpl_cntrl),
               .cfg_dpc_int_en                     (cfg_dpc_int_en),
               .cfg_dpc_err_cor_en                 (cfg_dpc_err_cor_en),
               .cfg_dpc_poison_tlp_egr_block_en    (cfg_dpc_poison_tlp_egr_block_en),
               .cfg_dpc_sw_trigger                 (cfg_dpc_sw_trigger),
               .cfg_dpc_dl_active_err_cor_en       (cfg_dpc_dl_active_err_cor_en),
               .cfg_dpc_trig_status                (cfg_dpc_trig_status),
               .dpc_triggered_detect               (dpc_triggered_detect),
               .dpc_int                            (dpc_int),
               .dpc_msi                            (dpc_msi),
               .dpc_reg_data                       (dpc_reg_data)
             );
end else begin : gen_cdm_dpc_reg
  assign cfg_dpc_int_msg_num                = 0;
  assign cfg_dpc_rp_ext_dpc                 = 0;
  assign cfg_dpc_poison_tlp_egr_blk_support = 0;
  assign cfg_dpc_sw_trig_support            = 0;
  assign cfg_dpc_rp_pio_log_size            = 0;
  assign cfg_dpc_dl_active_err_cor_support  = 0;
  assign cfg_dpc_trig_en                    = 0;
  assign cfg_dpc_cpl_cntrl                  = 0;
  assign cfg_dpc_int_en                     = 0;
  assign cfg_dpc_err_cor_en                 = 0;
  assign cfg_dpc_poison_tlp_egr_block_en    = 0;
  assign cfg_dpc_sw_trigger                 = 0;
  assign cfg_dpc_dl_active_err_cor_en       = 0;
  assign cfg_dpc_trig_status                = 0;
  assign dpc_triggered_detect               = 0;
  assign dpc_int                            = 0;
  assign dpc_msi                            = 0;
  assign dpc_reg_data                       = 0;

end // gen_cdm_dpc_reg
endgenerate

// =============================================================================
// Flit Logging Extended Capability
// =============================================================================
generate
if(FUNC_NUM==0) begin : gen_cdm_flit_logging_reg
  cdm_flit_logging_reg
    #(
                           .INST(INST),
                           .NR_REGS_FLIT_LOGGING(FLITLOGGING)
                          ,.RCRB(RCRB)
                         )
  u_cdm_flit_logging_reg (
                         .core_clk                       ( core_clk                           ),
                         .non_sticky_rst_n               ( non_sticky_rst_n                   ),
                         .sticky_rst_n                   ( sticky_rst_n                       ),                          
                         .cdm_clk_g                      ( cdm_clk_g                          ),
                         .lbc_cdm_data                   ( lbc_cdm_data                       ),
                         .lbc_cdm_dbi                    ( lbc_cdm_dbi                        ),
                         .dbi_ro_wr_en                   ( dbi_ro_wr_en                       ),
                         .flit_write_pulse               ( ecfg_write_pulse                   ),
                         .flit_logging_reg_id            ( flit_logging_reg_id                ),
                         .device_type                    ( device_type                        ),
                         .cxl_rcrb_enable                ( cxl_rcrb_enable                    ),
                         .flit_log                       ( cfg_flit_log                       ),
                         .link_wd_err_cnt_start          ( cfg_link_wd_err_cnt_start          ),
                         .flit_err_cnt                   ( cfg_flit_err_cnt                   ),
                         .flit_cnt                       ( cfg_flit_cnt                       ),
                         .invalid_flit_cnt               ( cfg_invalid_flit_cnt               ),
                         .interr_trg_evnt_cnt            ( cfg_interr_trg_evnt_cnt            ),
                         .interr_trg_evnt_cnt_clr        ( cfg_interr_trg_evnt_cnt_clr        ),
                         .lane_0_corr_cnt                ( cfg_lane_0_corr_cnt                ),
                         .lane_1_corr_cnt                ( cfg_lane_1_corr_cnt                ),
                         .lane_2_corr_cnt                ( cfg_lane_2_corr_cnt                ),
                         .lane_3_corr_cnt                ( cfg_lane_3_corr_cnt                ),
                         .lane_4_corr_cnt                ( cfg_lane_4_corr_cnt                ),
                         .lane_5_corr_cnt                ( cfg_lane_5_corr_cnt                ),
                         .lane_6_corr_cnt                ( cfg_lane_6_corr_cnt                ),
                         .lane_7_corr_cnt                ( cfg_lane_7_corr_cnt                ),
                         .lane_8_corr_cnt                ( cfg_lane_8_corr_cnt                ),
                         .lane_9_corr_cnt                ( cfg_lane_9_corr_cnt                ),
                         .lane_10_corr_cnt               ( cfg_lane_10_corr_cnt               ),
                         .lane_11_corr_cnt               ( cfg_lane_11_corr_cnt               ),
                         .lane_12_corr_cnt               ( cfg_lane_12_corr_cnt               ),
                         .lane_13_corr_cnt               ( cfg_lane_13_corr_cnt               ),
                         .lane_14_corr_cnt               ( cfg_lane_14_corr_cnt               ),
                         .lane_15_corr_cnt               ( cfg_lane_15_corr_cnt               ), 
                         .flit_logging_reg_data          ( flit_logging_reg_data              ),                                                             
                         .trg_evnt_cnt                   ( cfg_trg_evnt_cnt                   ),               
                         .evnt_to_cnt                    ( cfg_evnt_to_cnt                    ),               
                         .flit_err_cnt_en                ( cfg_flit_err_cnt_en                ), 
                         .interr_trg_evnt_cnt_ind        ( cfg_interr_trg_evnt_cnt_ind        ),
                         .fber_measurement_en            ( cfg_fber_measurement_en            ),
                         .clr_fber_cnt                   ( cfg_clr_fber_cnt                   ),
                         .gran_per_lane_err_rpt          ( cfg_gran_per_lane_err_rpt          ),
                         .rpt_longest_burst_vs_1st_burst ( cfg_rpt_longest_burst_vs_1st_burst ),
                         .flit_log_trg_evnt_msi          ( cfg_flit_log_trg_evnt_msi          ),
                         .pop_fifo_en                    ( cfg_pop_fifo_en                    )
                         );
end else begin : gen_cdm_flit_logging_reg
  assign flit_logging_reg_data              = {32{1'b0}};
  assign cfg_trg_evnt_cnt                   = {8{1'b0}} ;
  assign cfg_evnt_to_cnt                    = {2{1'b0}} ;
  assign cfg_flit_err_cnt_en                = 1'b0      ;
  assign cfg_interr_trg_evnt_cnt_ind        = 1'b0      ;
  assign cfg_fber_measurement_en            = 1'b0      ;
  assign cfg_clr_fber_cnt                   = 1'b0      ;
  assign cfg_gran_per_lane_err_rpt          = {2{1'b0}} ;
  assign cfg_rpt_longest_burst_vs_1st_burst = 1'b0      ;
  assign cfg_flit_log_trg_evnt_msi          = 1'b0      ;
  assign cfg_pop_fifo_en                    = 1'b0      ;
  end // gen_cdm_flit_logging_reg
endgenerate                      

// =============================================================================
//  Flit Performance Measurement
// =============================================================================
generate
if(FUNC_NUM==0) begin : gen_flit_perf_msur_reg

cdm_flit_prf_msur_reg
 #(   .INST(INST),
                          .NR_REGS_FLIT_PERF_MESUR(FLIT_PERF_MEASUREMENT)
                          ,.RCRB(RCRB)
                        )
u_cdm_flit_prf_msur_reg (
    // -------------- Inputs ----------------
                                  .core_clk                                (  core_clk                          )  // Core Clock
                                 ,.non_sticky_rst_n                        (  non_sticky_rst_n                  ) // Non-Sticky Reset
                                 ,.sticky_rst_n                            (  sticky_rst_n                      ) // Sticky Reset                           
                                 ,.cdm_clk_g                               (  cdm_clk_g                         )
                                 ,.lbc_cdm_data                            (  lbc_cdm_data                      ) // Write Data
                                 ,.lbc_cdm_dbi                             (  lbc_cdm_dbi                       )  // DBI Access
                                 ,.dbi_ro_wr_en                            (  dbi_ro_wr_en                      ) // DBI Write Enable of ReadOnly registers                        
                                 ,.flit_write_pulse                        (  ecfg_write_pulse                  ) // Write Byte Enable
                                 ,.flit_perf_msur_reg_id                   (  flit_perf_msur_reg_id             )   // Flit perf_msur Extended Capability Register ID
                                 ,.device_type                             (  device_type                       )
                                 ,.cxl_rcrb_enable                         ( cxl_rcrb_enable                    )                              
                                 ,.cfg_msi_en_pf0                          (  cfg_msi_en_pf0                    )
                                 ,.cfg_msix_en_pf0                         (  cfg_msix_en_pf0                   )
                                 ,.flit_latency_status                     (  cfg_flit_latency_status           )
                                 ,.flit_latency_value                      (  cfg_flit_latency_value            ) 
                                 ,.ltssm_st_trans1_status                  (  cfg_ltssm_st_trans1_status        ) 
                                 ,.ltssm_st_trans2_status                  (  cfg_ltssm_st_trans2_status        ) 
                                 ,.ltssm_st_trans3_status                  (  cfg_ltssm_st_trans3_status        ) 
                                 ,.ltssm_st_trans4_status                  (  cfg_ltssm_st_trans4_status        ) 
                                 ,.ltssm_st_trans5_status                  (  cfg_ltssm_st_trans5_status        ) 
                                 ,.ltssm_st_trans_latency                  (  cfg_ltssm_st_trans_latency        )

        // -------------- Outputs --------------//
                                 ,.flit_perf_msur_reg_data                 (  flit_perf_msur_reg_data            )
                                 ,.flit_perf_interr_vec                    (  cfg_flit_perf_interr_vec           )
                                 ,.ltssm_trck_reg_cnt                      (  cfg_ltssm_trck_reg_cnt             )
                                 ,.flit_response_type                      (  cfg_flit_response_type             )
                                 ,.flit_type_measured                      (  cfg_flit_type_measured             )
                                 ,.cfg_track_mode                          (  cfg_track_mode                     )
                                 ,.Ltssm_state_trans_trck                  (  cfg_Ltssm_st_trans_trck            )
                                 ,.trg_evnt_interr                         (  cfg_trg_evnt_interr                )
                                 ,.cfg_flit_latency_msi                    (  cfg_flit_latency_msi               )
                                 ,.sts_1_ltssm_trg_evnt_interr             (  cfg_sts_1_ltssm_trg_evnt_interr    )
                                 ,.cfg_sts_1_ltssm_latency_msi          (  cfg_sts_1_ltssm_latency_msi     )
);
end else begin : gen_flit_perf_msur_reg
assign flit_perf_msur_reg_data              = 32'b0 ;
assign cfg_flit_perf_interr_vec             = 10'b0 ;
assign cfg_ltssm_trck_reg_cnt               = 3'b0 ;
assign cfg_flit_response_type               = 3'b0 ;
assign cfg_flit_type_measured               = 2'b0 ;
assign cfg_track_mode                       = 1'b0 ;
assign cfg_Ltssm_st_trans_trck              = 5'b0 ;
assign cfg_trg_evnt_interr                  = 1'b0 ;
assign cfg_flit_latency_msi                 = 1'b0 ;
assign cfg_sts_1_ltssm_trg_evnt_interr      = 1'b0 ;
assign cfg_sts_1_ltssm_latency_msi       = 1'b0 ;
end //gen_flit_perf_msur_reg
endgenerate

generate
if(FUNC_NUM==0) begin : gen_flit_err_inj_reg
// =============================================================================
//Flit Error Injection Extended Capability
// =============================================================================
cdm_flit_err_inj_reg

 #( 
  .INST(INST), 
 .NR_REGS_FLIT_ERR_INJ(FLIT_ERR_INJ) 
 ,.RCRB(RCRB)
 )
 u_cdm_flit_err_inj_reg(                                                  
         . core_clk                                 (    core_clk                               )
         ,.non_sticky_rst_n                         (    non_sticky_rst_n                       )
         ,.sticky_rst_n                             (    sticky_rst_n                           )
                                                                                                
         ,.lbc_cdm_data                             (    lbc_cdm_data                           )
         ,.lbc_cdm_dbi                              (    lbc_cdm_dbi                            )
         ,.dbi_ro_wr_en                             (    dbi_ro_wr_en                           )
                                                                                                
         ,.flit_write_pulse                         (    ecfg_write_pulse                       )
         ,.flit_err_inj_reg_id                      (    flit_err_inj_reg_id                    )
         ,.device_type                              (    device_type                            )                                                                                     
         ,.cxl_rcrb_enable                          (    cxl_rcrb_enable                        )
         ,.cfg_inj_err_num                          (    cfg_inj_err_num                        )
         ,.cfg_flit_type_inj                        (    cfg_flit_type_inj                      )
         ,.cfg_flit_err_tx_inj_sts                  (    cfg_flit_err_tx_inj_sts                )
         ,.cfg_flit_err_rx_inj_sts                  (    cfg_flit_err_rx_inj_sts                )
         ,.cfg_ordr_set_tx_inj_sts_ts0              (    cfg_ordr_set_tx_inj_sts_ts0            )
         ,.cfg_ordr_set_tx_inj_sts_ts1              (    cfg_ordr_set_tx_inj_sts_ts1            )
         ,.cfg_ordr_set_tx_inj_sts_ts2              (    cfg_ordr_set_tx_inj_sts_ts2            )
         ,.cfg_ordr_set_tx_inj_sts_skp              (    cfg_ordr_set_tx_inj_sts_skp            )
         ,.cfg_ordr_set_tx_inj_sts_eieos            (    cfg_ordr_set_tx_inj_sts_eieos          )
         ,.cfg_ordr_set_tx_inj_sts_eios             (    cfg_ordr_set_tx_inj_sts_eios           )
         ,.cfg_ordr_set_tx_inj_sts_sds              (    cfg_ordr_set_tx_inj_sts_sds            )
         ,.cfg_ordr_set_tx_inj_sts_poll             (    cfg_ordr_set_tx_inj_sts_poll           )
         ,.cfg_ordr_set_tx_inj_sts_cfg              (    cfg_ordr_set_tx_inj_sts_cfg            )
         ,.cfg_ordr_set_tx_inj_sts_l0               (    cfg_ordr_set_tx_inj_sts_l0             )
         ,.cfg_ordr_set_tx_inj_sts_non_eq_recov     (    cfg_ordr_set_tx_inj_sts_non_eq_recov   )
         ,.cfg_ordr_set_tx_inj_sts_recov_eq_ph_1_0  (    cfg_ordr_set_tx_inj_sts_recov_eq_ph_1_0)
         ,.cfg_ordr_set_tx_inj_sts_recov_eq_ph_2    (    cfg_ordr_set_tx_inj_sts_recov_eq_ph_2  )
         ,.cfg_ordr_set_tx_inj_sts_recov_eq_ph_3    (    cfg_ordr_set_tx_inj_sts_recov_eq_ph_3  )
         ,.cfg_ordr_set_rx_inj_sts_ts0              (    cfg_ordr_set_rx_inj_sts_ts0            )
         ,.cfg_ordr_set_rx_inj_sts_ts1              (    cfg_ordr_set_rx_inj_sts_ts1            )
         ,.cfg_ordr_set_rx_inj_sts_ts2              (    cfg_ordr_set_rx_inj_sts_ts2            )
         ,.cfg_ordr_set_rx_inj_sts_skp              (    cfg_ordr_set_rx_inj_sts_skp            )
         ,.cfg_ordr_set_rx_inj_sts_eieos            (    cfg_ordr_set_rx_inj_sts_eieos          )
         ,.cfg_ordr_set_rx_inj_sts_eios             (    cfg_ordr_set_rx_inj_sts_eios           )
         ,.cfg_ordr_set_rx_inj_sts_sds              (    cfg_ordr_set_rx_inj_sts_sds            )
         ,.cfg_ordr_set_rx_inj_sts_poll             (    cfg_ordr_set_rx_inj_sts_poll           )
         ,.cfg_ordr_set_rx_inj_sts_cfg              (    cfg_ordr_set_rx_inj_sts_cfg            )
         ,.cfg_ordr_set_rx_inj_sts_l0               (    cfg_ordr_set_rx_inj_sts_l0             )
         ,.cfg_ordr_set_rx_inj_sts_non_eq_recov     (    cfg_ordr_set_rx_inj_sts_non_eq_recov   )
         ,.cfg_ordr_set_rx_inj_sts_recov_eq_ph_1_0  (    cfg_ordr_set_rx_inj_sts_recov_eq_ph_1_0)
         ,.cfg_ordr_set_rx_inj_sts_recov_eq_ph_2    (    cfg_ordr_set_rx_inj_sts_recov_eq_ph_2  )
         ,.cfg_ordr_set_rx_inj_sts_recov_eq_ph_3    (    cfg_ordr_set_rx_inj_sts_recov_eq_ph_3  )
                                                         
         ,.cfg_flit_err_inj_en                      (    cfg_flit_err_inj_en                    )
         ,.cfg_inj_err_tx_flit_ind                  (    cfg_inj_err_tx_flit_ind                )
         ,.cfg_inj_err_rx_flit_ind                  (    cfg_inj_err_rx_flit_ind                )
         ,.cfg_flit_err_inj_en_data_rate            (    cfg_flit_err_inj_en_data_rate          )
         ,.cfg_inj_err_spacing                      (    cfg_inj_err_spacing                    )
         ,.cfg_consec_err_inj                       (    cfg_consec_err_inj                     )
         ,.cfg_curr_inj_err_type                    (    cfg_curr_inj_err_type                  )
         ,.cfg_flit_err_off                         (    cfg_flit_err_off                       )
         ,.cfg_err_mag                              (    cfg_err_mag                            )
         ,.cfg_ordr_set_err_inj_en                  (    cfg_ordr_set_err_inj_en                )
         ,.cfg_inj_err_tx_ordr_set_ind              (    cfg_inj_err_tx_ordr_set_ind            )
         ,.cfg_inj_err_rx_ordr_set_ind              (    cfg_inj_err_rx_ordr_set_ind            )
         ,.cfg_ordr_set_inj_err_num                 (    cfg_ordr_set_inj_err_num               )
         ,.cfg_ordr_set_inj_err_spacing             (    cfg_ordr_set_inj_err_spacing           )
         ,.cfg_inj_err_ts0_os                       (    cfg_inj_err_ts0_os                     )
         ,.cfg_inj_err_ts1_os                       (    cfg_inj_err_ts1_os                     )
         ,.cfg_inj_err_ts2_os                       (    cfg_inj_err_ts2_os                     )
         ,.cfg_inj_err_skp_os                       (    cfg_inj_err_skp_os                     )
         ,.cfg_inj_err_eieos_os                     (    cfg_inj_err_eieos_os                   )
         ,.cfg_inj_err_eios_os                      (    cfg_inj_err_eios_os                    )
         ,.cfg_inj_err_sds_os                       (    cfg_inj_err_sds_os                     )
         ,.cfg_inj_err_poll_st                      (    cfg_inj_err_poll_st                    )
         ,.cfg_inj_err_cfg_st                       (    cfg_inj_err_cfg_st                     )
         ,.cfg_inj_err_l0_st                        (    cfg_inj_err_l0_st                      )
         ,.cfg_inj_err_non_eq_recov_st              (    cfg_inj_err_non_eq_recov_st            )
         ,.cfg_inj_err_recov_eq_ph_1_0              (    cfg_inj_err_recov_eq_ph_1_0            )
         ,.cfg_inj_err_recov_eq_ph_2                (    cfg_inj_err_recov_eq_ph_2              )
         ,.cfg_inj_err_recov_eq_ph_3                (    cfg_inj_err_recov_eq_ph_3              )
         ,.cfg_err_inj_bytes                        (    cfg_err_inj_bytes                      )
         ,.cfg_err_inj_lane_num                     (    cfg_err_inj_lane_num                   )
         ,.flit_err_inj_reg_data                    (    flit_err_inj_reg_data                  )
 );
end else begin : gen_flit_err_inj_reg
assign cfg_flit_err_inj_en                    = 1'b0 ;
assign cfg_inj_err_tx_flit_ind                = 1'b0 ;
assign cfg_inj_err_rx_flit_ind                = 1'b0 ;
assign cfg_flit_err_inj_en_data_rate          = 13'b0 ;
assign cfg_inj_err_num                        = 5'b0 ;
assign cfg_inj_err_spacing                    = 8'b0 ;
assign cfg_flit_type_inj                      = 3'b0 ;
assign cfg_consec_err_inj                     = 3'b0 ;
assign cfg_curr_inj_err_type                  = 2'b0 ;
assign cfg_flit_err_off                       = 7'b0 ;
assign cfg_err_mag                            = 8'b0 ;
assign cfg_ordr_set_err_inj_en                = 1'b0 ;
assign cfg_inj_err_tx_ordr_set_ind            = 1'b0 ;
assign cfg_inj_err_rx_ordr_set_ind            = 1'b0 ;
assign cfg_ordr_set_inj_err_num               = 5'b0 ;
assign cfg_ordr_set_inj_err_spacing           = 8'b0 ;
assign cfg_inj_err_ts0_os                     = 1'b0 ;
assign cfg_inj_err_ts1_os                     = 1'b0 ;
assign cfg_inj_err_ts2_os                     = 1'b0 ;
assign cfg_inj_err_skp_os                     = 1'b0 ;
assign cfg_inj_err_eieos_os                   = 1'b0 ;
assign cfg_inj_err_eios_os                    = 1'b0 ;
assign cfg_inj_err_sds_os                     = 1'b0 ;
assign cfg_inj_err_poll_st                    = 1'b0 ;
assign cfg_inj_err_cfg_st                     = 1'b0 ;
assign cfg_inj_err_l0_st                      = 1'b0 ;
assign cfg_inj_err_non_eq_recov_st            = 1'b0 ;
assign cfg_inj_err_recov_eq_ph_1_0            = 1'b0 ;
assign cfg_inj_err_recov_eq_ph_2              = 1'b0 ;
assign cfg_inj_err_recov_eq_ph_3              = 1'b0 ;
assign cfg_err_inj_bytes                      = 16'b0 ;
assign cfg_err_inj_lane_num                   = 16'b0 ;
assign flit_err_inj_reg_data                  = 32'b0 ;
end //gen_flit_err_inj_reg
endgenerate

//
// XALI Expansion coverage
//



endmodule
