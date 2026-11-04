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
// ---   $DateTime: 2024/02/08 08:06:28 $
// ---   $Revision: #20 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_link_ctrl.sv#20 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Link Layer initialization.
// CXL Link credit management
// CXL Retry Protocol
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_cdmregs_if.svh"
`include "CXL/svif/DWC_cxl_rxdl_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_arb_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_rbuf_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_pack_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_txtl_llctrl_if.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"


module DWC_cxl_mem_cache_link_ctrl
  import spif_pkg::*;                                                  // Import SPIF package
  import DWC_cxl_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
#(
  parameter TP = `TP,
    parameter   NW        = `CX_NW,                     // Number of 32-bit dwords handled by the datapath each clock. Note: mininum datapath is 128bits.
    parameter   DW        = (32*NW),                    // Width of datapath in bits.
    parameter   NBYTES    = 4*`CX_NW                    // Width of datapath protection in bits
)(
    DWC_cxl_clk_rst_if.slave_mp                   b_clk,                 // Clock and Reset interface
    DWC_cxl_cdmregs_if.slave_mp                   b_cdm,                 // CDM interface
    DWC_cxl_rxdl_llctrl_if.slave_mp               b_rxdl_llctrl,         // Receiver link layer interface to link layer control
    spif_if.slave_mp                              b_vlsm_llctrl,         // Link Layer to VLSM SPIF Interface for CXL.cachemem
    spif_if.cfgi_master_mp                        b_cfgi_spif,           // CFGI SPIF interface
    DWC_cxl_txtl_llctrl_if.slave_host_mp          b_txtl_host,           // Transaction Layer Interface for Host Channels
    DWC_cxl_txtl_llctrl_if.slave_dev_mp           b_txtl_dev,            // Transaction Layer Interface for Device Channels
    DWC_cxl_rbuf_llctrl_if.master_mp              b_rbuf_llctrl,         // Retry Buffer RAM Interface
    input                                         pm_req_l1,             // PM request L1 Entry
    input                                         pm_req_l2,             // PM request L2 Entry
    input                                         lp_cxl_l1_exit,        // PM request to CXL.cachemem Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
    input                                         lp_cxl_clk_ack,        // SPIF: CXL.cachemem Link Layer acknowledges LogPHY request to remove the clock gating
    input                                         lp_cxl_wake_req,       // SPIF: CXL.cachemem Link Layer requests LogPHY to remove the clock gating
    input                                         cxl_rx_active_sts,     // RX Interface Activation Status
    output ras_dp_err_log_t                       ras_dp_err_log,
    output [CXL_TX_LL_RAS_UNCORR_NUM-1:0]         ras_dp_uncorr_err,
    input  ras_dp_err_inj_t                       ras_dp_err_inj,
    output                                        cxl_ll_idle,           // CXL LL Controller is in Idle state
    output                                        link_tx_deinit_req,    // Tx Link deinit for app interface
    output                                        cxl_link_up,           // Indicates that CXL Link is up
    output protocol_cfg_t                         cxl_protocol_cfg       // Protocol Configuration for CXL Controller
);

// Local Interfaces
DWC_cxl_pack_llctrl_if        b_pack_llctrl();          // Link Layer Controller to Flit Packer Interface
DWC_cxl_pack_llctrl_if        b_pack();                 // Flit Packer to Link Layer Controller Interface
DWC_cxl_pack_llctrl_if        b_mux_pack();             // CXS Interface and Flit Packer to Link Layer Controller Interface MUX

// Declarations
wire                          cxl_ll_init_crd;          // Link Init - Start Credit Initialization
wire                          cxl_ll_init_done;         // Link Init - INIT.Param exchange done  
wire                          cxl_ll_init_crd_done;     // Link Init - Credit Initialization Done Signal
wire [(ESEQ_WD - 1) : 0]      cxl_ll_init_llr_wrap;     // Link Init - Wrap Value
wire [(LL_CSR_STATE_WD-1):0]  cxl_ll_init_state;        // Link Init - Current State
wire                          cxl_retryable_flit_ena;   // Enable retryable flit based on RBUF NumFreeBuf
wire                          cxl_viral_llcrd_req;      // Flit Interface - LLCRD Flit Insertion request in Viral state
wire                          cxl_fgen_ack_timer_rst;   // Flit Interface - Reset Acknowledge Flash Time
wire [(ACK_CNT_WD - 1) : 0]   cxl_tx_full_ack;          // Flit Interface - Full Ack in the transmitted Protocol/Control flit
wire                          cxl_retryable_valid;      // Flit Interface - Flit Valid for Retry Buffer
wire [(CXL_DATA_WD - 1) : 0]  cxl_retryable_flit;     // Flit Interface - Flit Data for Retry Buffer

wire                          cxl_ll_arb_flit_valid;    // Flit Interface - Flit Valid for ARB/MUX
wire                          cxl_ll_arb_flit_sof;      // Flit Interface - Flit SOF for ARB/MUX
wire                          cxl_ll_arb_flit_eof;      // Flit Interface - Flit EOF for ARB/MUX
wire                          cxl_ll_arb_flit_enf;      // Flit Interface - Flit ENF for ARB/MUX
wire                          cxl_ll_arb_flit_retry;    // Flit Interface - Flit Replayed from Retry Buffer for ARB/MUX
wire [(ARBMUX_FLIT_WD-1) : 0] cxl_ll_arb_flit;          // Flit Interface - Flit Data for ARB/MUX
wire [CXL_DATA_PROT_WD-1 : 0] cxl_ll_arb_flit_chk;      // Flit Interface - Flit Data for ARB/MUX ECC Protection
wire                          cxl_ll_arb_flit_lp_pri;   // Flit Interface - Priority Indication
wire                          cxl_ll_arb_flit_err;      // Flit Interface - Viral Req in 256B mode for Arb/Mux
wire [4:0]                    cxl_ll_packer_data_en;    // Flit Packe Data Header Enable
wire                          cxl_ll_packer_halt;       // Flit Interface - Back-Pressure the Flit Packer !!!!!
wire                          cxl_ll_rbuf_halt;         // Flit Interface - Retry Buffer Halt
wire                          cxl_packer_flit_valid;    // Flit Interface - Packer Flit Valid
wire [CXL_DATA_WD-1:0]        cxl_packer_flit_data;     // Flit Interface - Packer Flit Data
wire [CXL_DATA_PROT_WD-1 : 0] cxl_packer_flit_data_chk; // Flit Interface - Flit Data for ARB/MUX ECC Protection
wire                          cxl_packer_flit_adf;      // Flit Interface - Packer Flit All Data Flit (ADF) - corresponds to SOF
wire                          cxl_packer_flit_last;     // Flit Interface - Packer Flit Last Indication - corresponds to EOF
wire                          cxl_packer_idle;          // Flit Interface - Packer Idle State
wire                          cxl_packer_llctrl_halt;   // Flit Interface - LLCTRL Backpressure by Packer
wire                          cxl_llctrl_packer_halt;   // Flit Interface - Packer Backpressure by LLCTRL
wire [(CRD_RET_WD - 1) : 0]   cxl_cache_data_crd;       // Flit Interface - Cache Data Credits in the Transmitted Flit
wire [(CRD_RET_WD - 1) : 0]   cxl_cache_req_crd;        // Flit Interface - Cache Request Credits in the Transmitted Flit
wire [(CRD_RET_WD - 1) : 0]   cxl_cache_rsp_crd;        // Flit Interface - Cache Response Credits in the Transmitted Flit
wire [(CRD_RET_WD - 1) : 0]   cxl_mem_data_crd;         // Flit Interface - Mem Data Credits in the Transmitted Flit
wire [(CRD_RET_WD - 1) : 0]   cxl_mem_req_crd;          // Flit Interface - Mem Request Credits in the Transmitted Flit
wire [(CRD_RET_WD - 1) : 0]   cxl_mem_rsp_crd;          // Flit Interface - Mem Response Credits in the Transmitted Flit
wire                          cxl_lrsm_retry_hit;       // LRSM - Retry Threshold Hit
wire                          cxl_lrsm_reinit_hit;      // LRSM - Reinit Threshold Hit
wire                          cxl_lrsm_uc_err;          // LRSM - Uncorrectable Error
lrsm_state_e                  cxl_lrsm_state;           // LRSM - State
wire                          cxl_lrsm_drop_flits;      // LRSM - Signal to Receiver to start dropping flits
wire                          cxl_lrsm_req_retrain;     // LRSM - Request Link Retrain
wire                          cxl_rrsm_active;          // RRSM - FSM is not in NORMAL state
wire                          cxl_rrsm_rbuf_req;        // RRSM - Request RBUF to start offloading data
wire                          cxl_rbuf_flit_valid;      // RBUF - Retry Buffer Flit Valid
wire [CXL_DATA_WD-1 : 0]      cxl_rbuf_flit;            // RBUF - Retry Buffer Flit Data
wire                          cxl_rbuf_llcrd_req;       // RBUF - LLCRD Flit Insertion Request
wire                          cxl_rbuf_eseq_ovflw;      // RBUF - Retry buffer ESEQ Overflow
wire [(RBUF_ADD_WD - 1) : 0]  cxl_rbuf_consumed;        // RBUF - Retry Buffer Number of Consumed Entries
wire [(RBUF_ADD_WD - 1) : 0]  cxl_rbuf_numfree;         // RBUF - Retry Buffer Number of Free Entries
wire                          cxl_rbuf_en;              // RBUF - RAM Read Enable
wire                          cxl_rbuf_wen;             // RBUF - RAM Write Enable
wire [(RBUF_ADD_WD - 1) : 0]  cxl_rbuf_addr;            // RBUF - RAM Address
wire                          cxl_rbuf_addr_par;        // RBUF - RAM Address Parity
wire [(RBUF_DATA_WD - 1) : 0] cxl_rbuf_wdata;           // RBUF - RAM Write Data
wire                          flit_clk_s;               // Retry Timer Counter Increment
wire                          cxl_retry_normal;         // RRSM and LRSM are in NORMAL state
wire [(ACK_CNT_WD - 1) : 0]   cxl_ack_cnt_full;         // Credit Controller - Full Ack Counter
wire                          cxl_hdr_ack_bit;          // Credit Controller - Protocol Flit Header Ack Bit
wire                          cxl_ack_cnt_force_llcrd;  // Credit Controller - Force ACK LLCRD Request
wire                          cxl_crd_ctrl_init_done;   // Credit Controller - Credit Initialization is complete
wire                          cxl_link_crd_ack;         // Credit Controller - Credit Initialization is complete
wire [(FLIT_CRD_WD - 1) : 0]  cxl_hdr_data_crd;         // Credit Controller - Flit Header Data Credits
wire [(FLIT_CRD_WD - 1) : 0]  cxl_hdr_rsp_crd;          // Credit Controller - Flit Header Response Credits
wire [(FLIT_CRD_WD - 1) : 0]  cxl_hdr_req_crd;          // Credit Controller - Flit Header Request Credits
wire [15:0]                   cxl_hdr_256B_crd;         // Crdit Controller - 256B Flit RX Credit Return (2B CRD)
wire                          cxl_llctrl_halt;          // LLCTRL Flit Gen - LLCTRL Flit Halt
wire                          cxl_init_param_req;       // LLCTRL Flit Gen - INIT requests Init.Param sequence
wire [63:0]                   cxl_init_param_payload;   // LLCTRL Flit Gen - INIT requests Init.Param payload
wire                          cxl_lrsm_retry_req;       // LLCTRL Flit Gen - LRSM requests Retry.Req sequence
wire [63:0]                   cxl_lrsm_retry_payload;   // LLCTRL Flit Gen - LRSM requests Retry.Req payload
wire                          cxl_lrsm_idle_req;        // LLCTRL Flit Gen - LRSM requests Retry.Idle flit
wire                          cxl_rrsm_retry_ack;       // LLCTRL Flit Gen - RRSM requests Retry.Ack sequence
wire [63:0]                   cxl_rrsm_retry_payload;   // LLCTRL Flit Gen - RRSM requests Retry.Ack payload
wire                          cxl_llcrd_req;            // LLCTRL Flit Gen - CRD requests LLCRD sequence
wire [63:0]                   cxl_llcrd_payload;        // LLCTRL Flit Gen - CRD requests LLCRD payload
wire                          cxl_init_param_sent;      // LLCTRL Flit Gen - INIT Init.Param sent
wire                          cxl_lrsm_retry_req_sent;  // LLCTRL Flit Gen - LRSM Retry.Req sent
wire                          cxl_rrsm_retry_ack_sent;  // LLCTRL Flit Gen - RRSM Retry.Ack sent
wire                          cxl_llcrd_sent;           // LLCTRL Flit Gen - INIT LLCRD sent
wire [127:0]                  cxl_llctrl_flit;          // LLCTRL Flit Gen - LLCTRL Flit
wire [CXL_DATA_PROT_WD-1 : 0] cxl_llctrl_flit_chk;      // LLCTRL Flit Gen - LLCTRL Flit Protection
wire                          cxl_llctrl_flit_valid;
wire                          cxl_llctrl_flit_sof;
wire                          cxl_llctrl_flit_eof;
wire [(TX_CREDIT_WD - 1) : 0] cxl_ll_cache_data_crd;    // Credit Controller - Cache Data Available TX Credits
wire [(TX_CREDIT_WD - 1) : 0] cxl_ll_cache_rsp_crd;     // Credit Controller - Cache Response Available TX Credits
wire [(TX_CREDIT_WD - 1) : 0] cxl_ll_cache_req_crd;     // Credit Controller - Cache Request Available TX Credits
wire [(RX_CREDIT_WD - 1) : 0] cxl_rx_cache_data_crdret; // Credit Controller - Cache Data Accumulated Credit Return
wire [(RX_CREDIT_WD - 1) : 0] cxl_rx_cache_req_crdret;  // Credit Controller - Cache Request Accumulated Credit Return
wire [(RX_CREDIT_WD - 1) : 0] cxl_rx_cache_rsp_crdret;  // Credit Controller - Cache Response Accumulated Credit Return
wire [TX_CRDIF_WIDTH-1:0]     cxl_ll_cache_data_gnt;    // Credit Controller - Cache Data TX Credits Granted to Packer
wire [TX_CRDIF_WIDTH-1:0]     cxl_ll_cache_rsp_gnt;     // Credit Controller - Cache Response TX Credits Granted to Packer
wire [TX_CRDIF_WIDTH-1:0]     cxl_ll_cache_req_gnt;     // Credit Controller - Cache Request TX Credits Granted to Packer
wire [(TX_CREDIT_WD - 1) : 0] cxl_ll_mem_data_crd;      // Credit Controller - Mem Data Available TX Credits
wire [(TX_CREDIT_WD - 1) : 0] cxl_ll_mem_ndr_crd;       // Credit Controller - Mem Request/Response Available TX Credits
wire [(RX_CREDIT_WD - 1) : 0] cxl_rx_mem_data_crdret;   // Credit Controller - Mem Data Accumulated Credit Return
wire [(RX_CREDIT_WD - 1) : 0] cxl_rx_mem_ndr_crdret;    // Credit Controller - Mem Request/Response Accumulated Credit Return
wire [(RX_CREDIT_WD - 1) : 0] cxl_rx_mem_bi_crdret;    // Credit Controller - Mem Request/Response Accumulated Credit Return

wire [TX_CRDIF_WIDTH-1:0]     cxl_ll_mem_dr_gnt;        // Credit Controller - Mem Data TX Credits Granted to Packer
wire [TX_CRDIF_WIDTH-1:0]     cxl_ll_mem_ndr_gnt;       // Credit Controller - Mem Request/Response TX Credits Granted to Packer
wire [TX_CREDIT_WD-1:0]       cxl_ll_mem_bi_crd;        // Credit Controller - CXL.mem BI-Snoop/Response credit
wire [TX_CRDIF_WIDTH-1:0]     cxl_ll_mem_bi_gnt;        // Credit Controller - CXL.mem BI-Snoop/Response grant
CRD_256B_t                    cxl_256B_tx_crdret;
//logic                         cxl_packer_empty_flit;
wire                          link_layer_clk_s    ;   // Link Layer Clock for Ack Flush Timer
wire                          cxl_link_retrain_ack;   // Link Retrain Acknowledge
wire                          cxl_link_stall_ack;     // Link Stall Acknowledge
wire                          cxl_link_in_retrain;    // Link in Retrain 
wire                          cxl_link_retrain_exit;  // Link Retrain Exit
wire                          cxl_link_enable;
wire                          cxl_link_pm_l1_req;
wire                          cxl_link_pm_l2_req;
wire                          cxl_link_init_req;
wire                          xplh_arbmux_ctrl_pending;  // XPLH ARB/MUX pending CXL.cachemem flit indication
logic                         s_cxl_force_llcrd_256byte, 
                              s_packer_force_crd;        // Force Sending credit to the packer
wire                          lp_protocol_vld;           // Link Layer Protocol Valid
protocol_type_e               lp_protocol;               // Link Layer Protocol Type
protocol_fmt_e                lp_protocol_fmt;           // Link Layer Protocol Flit Format


localparam CXL_TX_LL_RAS_ERR_LOG_NUM = 1;

logic            [CXL_RBUF_RAS_UNCORR_NUM-1:0]     ras_dp_uncorr_err_rbuf;
ras_dp_err_inj_t                                   ras_dp_err_inj_tx_dl;
ras_dp_err_log_t                                   ras_dp_err_log_rbuf;    // Error Logs from RBUF
ras_dp_err_log_t [CXL_TX_LL_RAS_ERR_LOG_NUM-1:0]   ras_dp_err_log_arr;     // Error Logs from Link Layer

assign ras_dp_err_log_arr = {ras_dp_err_log_rbuf};
assign ras_dp_uncorr_err = {ras_dp_uncorr_err_rbuf};

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( CXL_TX_LL_RAS_ERR_LOG_NUM )
) u_cxl_tx_dl_ras_dp_err_mgr (
    .clk                ( b_clk.s_core_clk            ),
    .rst_n              ( b_clk.s_core_rst_n          ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj              ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_tx_dl        ),
    .in_ras_dp_err_log  ( ras_dp_err_log_arr          ),
    .out_ras_dp_err_log ( ras_dp_err_log              )
);



// CDM Interface Output Connection
assign s_packer_force_crd                  = (s_cxl_force_llcrd_256byte && b_vlsm_llctrl.s_pl_rx_active_req) || cxl_ll_init_crd;
assign b_cdm.s_cfg_tx_cache_req_credits    = cxl_ll_cache_req_crd;
assign b_cdm.s_cfg_tx_cache_rsp_credits    = cxl_ll_cache_rsp_crd;
assign b_cdm.s_cfg_tx_cache_data_credits   = cxl_ll_cache_data_crd;

assign b_cdm.s_cfg_rx_cache_req_crdrets    = cxl_rx_cache_req_crdret;
assign b_cdm.s_cfg_rx_cache_rsp_crdrets    = cxl_rx_cache_rsp_crdret;
assign b_cdm.s_cfg_rx_cache_data_crdrets   = cxl_rx_cache_data_crdret;
assign b_cdm.s_cfg_tx_mem_data_credits     = cxl_ll_mem_data_crd;
assign b_cdm.s_cfg_tx_mem_req_rsp_credits  = cxl_ll_mem_ndr_crd;
assign b_cdm.s_cfg_tx_mem_bi_credits       = cxl_ll_mem_bi_crd;
assign b_cdm.s_cfg_rx_mem_bi_crdrets       = cxl_rx_mem_bi_crdret;


assign b_cdm.s_cfg_rx_mem_data_crdrets     = cxl_rx_mem_data_crdret;
assign b_cdm.s_cfg_rx_mem_req_rsp_crdrets  = cxl_rx_mem_ndr_crdret;

assign b_cdm.s_cfg_ll_init_state           = cxl_ll_init_state;
assign b_cdm.s_cfg_ll_rbuf_consumed        = cxl_rbuf_consumed;
assign b_cdm.s_lrsm_state                  = cxl_lrsm_state;
assign b_cdm.s_lrsm_uc_err                 = cxl_lrsm_uc_err;
assign b_cdm.s_cxl_lrsm_retry_hit          = cxl_lrsm_retry_hit;
assign b_cdm.s_cxl_lrsm_reinit_hit         = cxl_lrsm_reinit_hit;
assign b_cdm.s_cxl_rbuf_eseq_ovflw         = cxl_rbuf_eseq_ovflw;


// RXDL LLCTRL Interface Output Connection
assign b_rxdl_llctrl.s_cxl_lrsm_drop_flits  = cxl_lrsm_drop_flits && !cxl_protocol_cfg.cxl_pcie_flit_mode;
assign b_rxdl_llctrl.s_cxl_vlsm_recovery    = cxl_link_in_retrain;

// -------------------------------------------------------------------------------------
// Imitate ARB/MUX vLSM Interface for testbench (To be removed!!!)
// -------------------------------------------------------------------------------------
DWC_cxl_arb_llctrl_if   b_tx_arbmux_ctrl();          // ARB/MUX link layer control Interface
DWC_cxl_arb_llctrl_if   b_tx_arbser_ctrl();

assign b_tx_arbmux_ctrl.s_arb_mux_flit_vld     = cxl_ll_arb_flit_valid;
assign b_tx_arbmux_ctrl.s_arb_mux_flit_sof     = cxl_ll_arb_flit_sof;
assign b_tx_arbmux_ctrl.s_arb_mux_flit_eof     = {2{cxl_ll_arb_flit_eof}};
assign b_tx_arbmux_ctrl.s_arb_mux_flit_enf     = cxl_ll_arb_flit_enf;
assign b_tx_arbmux_ctrl.s_arb_mux_flit_eof_err = cxl_ll_arb_flit_err;
assign b_tx_arbmux_ctrl.s_arb_mux_flit_pri     = cxl_ll_arb_flit_lp_pri;
assign b_tx_arbmux_ctrl.s_arb_mux_flit_data    = { cxl_ll_arb_flit_chk, cxl_ll_arb_flit};

assign b_tx_arbser_ctrl.s_arb_mux_flit_halt = !b_vlsm_llctrl.s_pl_trdy;

// If Serializer does not exist then assign b_tx_arbmux_ctrl to b_tx_arbser_ctrl
assign b_tx_arbmux_ctrl.s_arb_mux_flit_halt = b_tx_arbser_ctrl.s_arb_mux_flit_halt;
assign b_tx_arbser_ctrl.s_arb_mux_flit_vld  = b_tx_arbmux_ctrl.s_arb_mux_flit_vld ;
assign b_tx_arbser_ctrl.s_arb_mux_flit_sof  = b_tx_arbmux_ctrl.s_arb_mux_flit_sof ;
assign b_tx_arbser_ctrl.s_arb_mux_flit_eof  = b_tx_arbmux_ctrl.s_arb_mux_flit_eof ;
assign b_tx_arbser_ctrl.s_arb_mux_flit_enf  = b_tx_arbmux_ctrl.s_arb_mux_flit_enf ;
// TBD: Align signals width of s_arb_mux_xplh_data and s_arb_mux_flit_data
//assign b_tx_arbser_ctrl.s_arb_mux_xplh_data = b_tx_arbmux_ctrl.s_arb_mux_flit_data;
assign b_tx_arbser_ctrl.s_arb_mux_xplh_data[ARBMUX_XPLH_WD-1:0] = {b_tx_arbmux_ctrl.s_arb_mux_flit_data[ARBMUX_68B_DATA_WD+:16], b_tx_arbmux_ctrl.s_arb_mux_flit_data[ARBMUX_DATA_WD-1:0]};
assign b_tx_arbser_ctrl.s_arb_mux_xplh_data[ARBMUX_XPLH_WD+:ARBMUX_XPLH_PROT_WD] = {{ARBMUX_XPLH_PROT_WD-ARBMUX_DATA_PROT_WD{1'b1}},b_tx_arbmux_ctrl.s_arb_mux_flit_data[ARBMUX_FLIT_WD+:ARBMUX_DATA_PROT_WD]};

assign b_tx_arbser_ctrl.s_arb_mux_flit_eof_err = b_tx_arbmux_ctrl.s_arb_mux_flit_eof_err;
assign b_tx_arbser_ctrl.s_arb_mux_flit_pri     = b_tx_arbmux_ctrl.s_arb_mux_flit_pri;

assign xplh_arbmux_ctrl_pending = b_tx_arbser_ctrl.s_arb_mux_flit_vld;
// -------------------------------------------------------------------------------------

// Retry Buffer RAM Interface
assign b_rbuf_llctrl.s_cxl_rbuf_addr  = cxl_rbuf_addr;
assign b_rbuf_llctrl.s_cxl_rbuf_addr_par = cxl_rbuf_addr_par;
assign b_rbuf_llctrl.s_cxl_rbuf_en    = cxl_rbuf_en;
assign b_rbuf_llctrl.s_cxl_rbuf_wen   = cxl_rbuf_wen;
assign b_rbuf_llctrl.s_cxl_rbuf_wdata = cxl_rbuf_wdata;

// Output Port Assignments
assign cxl_link_up = cxl_protocol_cfg.cxl_pcie_flit_mode ? cxl_ll_init_done : cxl_ll_init_crd_done;

// Internal Connections
assign cxl_retry_normal  = ~cxl_rrsm_active & ~b_rxdl_llctrl.s_cxl_lrsm_drop_flits;

// Flit Packer Backpressure from LLCTRL (Flit Interface)
// On entry to Hot-Reset/Link Disable state, do not assert halt signal to flush the Transaction Layer through the Flit Packer
assign cxl_llctrl_packer_halt = cxl_ll_packer_halt;

// -------------------------------------------------------------------------------------
// Link Layer Controller to Flit Packer Interface
// -------------------------------------------------------------------------------------
assign b_pack_llctrl.s_cxl_hdr_ack_bit       = cxl_hdr_ack_bit;
assign b_pack_llctrl.s_cxl_hdr_data_crd      = cxl_hdr_data_crd;
assign b_pack_llctrl.s_cxl_hdr_rsp_crd       = cxl_hdr_rsp_crd;
assign b_pack_llctrl.s_cxl_hdr_req_crd       = cxl_hdr_req_crd;
assign b_pack_llctrl.s_cxl_ll_packer_halt    = cxl_llctrl_packer_halt;
assign b_pack_llctrl.s_cxl_ll_packer_data_en = cxl_ll_packer_data_en;
// On entry to Hot-Reset/Link Disable state, enable all the credits to flush the Transaction Layer through the Flit Packer
assign b_pack_llctrl.s_cxl_ll_mem_mdh_en     = ~b_cdm.s_cfg_cxl_mdh_disable;
assign b_pack_llctrl.s_cxl_ll_mem_dr_gnt     = cxl_ll_mem_dr_gnt;
assign b_pack_llctrl.s_cxl_ll_mem_ndr_gnt    = cxl_ll_mem_ndr_gnt;
assign b_pack_llctrl.s_cxl_ll_mem_bi_gnt     = cxl_ll_mem_bi_gnt;
assign b_pack_llctrl.s_cxl_ll_cache_rsp_gnt  = cxl_ll_cache_rsp_gnt;
assign b_pack_llctrl.s_cxl_ll_cache_req_gnt  = cxl_ll_cache_req_gnt;
assign b_pack_llctrl.s_cxl_ll_cache_data_gnt = cxl_ll_cache_data_gnt;
assign b_pack_llctrl.s_cxl_ll_cache_mdh_en   = ~b_cdm.s_cfg_cxl_mdh_disable;
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Multiplex between IDE and Flit Packer Interface on Flit Interface inputs
// -------------------------------------------------------------------------------------
 
assign cxl_packer_flit_valid  = b_mux_pack.s_cxl_packer_valid       ;
assign cxl_packer_flit_data   = b_mux_pack.s_cxl_packer_flit        ;
assign cxl_packer_flit_adf    = b_mux_pack.s_cxl_packer_all_data    ;
assign cxl_packer_flit_last   = b_mux_pack.s_cxl_packer_last        ;
assign cxl_packer_idle        = b_mux_pack.s_cxl_packer_idle        ;
assign cxl_packer_llctrl_halt = b_mux_pack.s_cxl_packer_llctrl_halt ;
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Multiplex between CXS and Channel Message Interface Packers
// -------------------------------------------------------------------------------------
assign cxl_link_crd_ack                    = cxl_crd_ctrl_init_done          ;

assign b_mux_pack.s_cxl_app_pending        = b_pack.s_cxl_app_pending        ;
assign b_mux_pack.s_cxl_packer_valid       = b_pack.s_cxl_packer_valid       ;
assign b_mux_pack.s_cxl_packer_flit        = b_pack.s_cxl_packer_flit        ;
assign b_mux_pack.s_cxl_packer_all_data    = b_pack.s_cxl_packer_all_data    ;
assign b_mux_pack.s_cxl_packer_last        = b_pack.s_cxl_packer_last        ;
assign b_mux_pack.s_cxl_packer_idle        = b_pack.s_cxl_packer_idle        ;
assign b_mux_pack.s_cxl_packer_llctrl_halt = b_pack.s_cxl_packer_llctrl_halt ;
assign b_mux_pack.s_cxl_cache_req_valid    = b_pack.s_cxl_cache_req_valid    ;
assign b_mux_pack.s_cxl_cache_rsp_valid    = b_pack.s_cxl_cache_rsp_valid    ;
assign b_mux_pack.s_cxl_cache_dhdr_valid   = b_pack.s_cxl_cache_dhdr_valid   ;
assign b_mux_pack.s_cxl_mem_ndr_valid      = b_pack.s_cxl_mem_ndr_valid      ;
assign b_mux_pack.s_cxl_mem_dr_valid       = b_pack.s_cxl_mem_dr_valid       ;
assign b_mux_pack.s_cxl_mem_bi_valid       = b_pack.s_cxl_mem_bi_valid       ;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Link Layer State FSM Instantiation
// -------------------------------------------------------------------------------------
assign b_vlsm_llctrl.s_lp_stall_ack     = cxl_link_stall_ack;
assign b_vlsm_llctrl.s_lp_rx_active_sts = cxl_rx_active_sts;
assign b_vlsm_llctrl.s_lp_dl_active     = cxl_ll_init_done && !(b_vlsm_llctrl.s_pl_state_sts inside {RESET, DISABLED, LINKRESET, LINKERROR});
assign b_vlsm_llctrl.s_lp_wake_req      = lp_cxl_wake_req;
assign b_vlsm_llctrl.s_lp_clk_ack       = lp_cxl_clk_ack;
assign b_vlsm_llctrl.s_lp_linkerror     = 1'b0
 ;
assign b_vlsm_llctrl.s_lp_linkmode_rmt  = '0;
assign b_vlsm_llctrl.s_lp_linkmode_pri  = '0;
assign b_vlsm_llctrl.s_lp_linkmode      = '0;

assign b_vlsm_llctrl.s_lp_stream        = SID_CXL_CM;
assign b_vlsm_llctrl.s_lp_irdy          = b_tx_arbser_ctrl.s_arb_mux_flit_vld;
assign b_vlsm_llctrl.s_lp_pri           = {1'b0, !b_tx_arbser_ctrl.s_arb_mux_flit_pri}; // active low priority at SPIF
assign b_vlsm_llctrl.s_lp_valid         = b_tx_arbser_ctrl.s_arb_mux_flit_vld;
assign b_vlsm_llctrl.s_lp_data          = b_tx_arbser_ctrl.s_arb_mux_xplh_data[DW-1:0];
assign b_vlsm_llctrl.s_lp_crc_valid     = cxl_protocol_cfg.cxl_pcie_flit_mode ? 1'b0  : b_tx_arbser_ctrl.s_arb_mux_flit_eof[1];
assign b_vlsm_llctrl.s_lp_crc_data      = cxl_protocol_cfg.cxl_pcie_flit_mode ? 16'd0 : b_tx_arbser_ctrl.s_arb_mux_xplh_data[ARBMUX_68B_XPLH_WD-1 -:16];
assign b_vlsm_llctrl.s_lp_dllp_valid    = '0; // DLLP Interface not applicable to CXL.cachemem
assign b_vlsm_llctrl.s_lp_dllp_ofc      = '0; // DLLP Interface not applicable to CXL.cachemem
assign b_vlsm_llctrl.s_lp_dllp_data     = '0; // DLLP Interface not applicable to CXL.cachemem
assign b_vlsm_llctrl.s_lp_nop_flit      = b_tx_arbser_ctrl.s_arb_mux_flit_enf;
assign b_vlsm_llctrl.s_lp_corrupt_crc   = b_tx_arbser_ctrl.s_arb_mux_flit_eof_err;                      //viral indication to xplh, aligned with eof
//  {crc prot, data prot, crc, data}                                  DW=256: 256+16 + 256/8      (256+16)+32bit prot + 2bit crc prot  
//  (2bit      64/32bit  16bit 512/256bit                             DW=512: 512+16 + 512/8      (512+16)+64bit prot + 2bit crc prot
assign b_vlsm_llctrl.s_lp_data_chk      = b_tx_arbser_ctrl.s_arb_mux_xplh_data[DW+16+NBYTES-1  : DW+16];
assign b_vlsm_llctrl.s_lp_rasdp_error   = '0;

// CFGI SPIF Interface Connections
assign b_vlsm_llctrl.s_lp_cfg_vld       = b_cfgi_spif.s_lp_cfg_vld;
assign b_vlsm_llctrl.s_lp_cfg_data      = b_cfgi_spif.s_lp_cfg_data;
assign b_cfgi_spif.s_pl_cfg_vld         = b_vlsm_llctrl.s_pl_cfg_vld;
assign b_cfgi_spif.s_pl_cfg_data        = b_vlsm_llctrl.s_pl_cfg_data;

// Tie-off DLLP/TLP signals on CXL.cachemem SPIF interface
assign b_vlsm_llctrl.s_lp_dlp_start     = '0;
assign b_vlsm_llctrl.s_lp_dlp_end       = '0;
assign b_vlsm_llctrl.s_lp_tlp_start     = '0;
assign b_vlsm_llctrl.s_lp_tlp_end       = '0;

// Retrain acknowledge for Link Layer requesting PHY to retrain
assign cxl_link_retrain_ack             = (b_vlsm_llctrl.s_lp_state_req == RETRAIN) && (b_vlsm_llctrl.s_pl_state_sts == RETRAIN);
// PHY is going into retrain indecation, is only used in 68B flit mode
assign cxl_link_in_retrain              = (b_vlsm_llctrl.s_pl_state_sts == RETRAIN) && (!cxl_protocol_cfg.cxl_pcie_flit_mode);
// PHY exits from the retrain
assign cxl_link_retrain_exit            = (b_vlsm_llctrl.s_pl_state_sts == ACTIVE) && !b_vlsm_llctrl.s_pl_stall_req;
// Enable CXL Link initialization when vLSM de-asserts pl_block_dl_init on the SPIF interface
assign cxl_link_init_req                = !b_vlsm_llctrl.s_pl_block_dl_init;

assign cxl_link_enable                  = b_vlsm_llctrl.s_pl_link_up && cxl_protocol_cfg.cxl_mode_enable;
// (b_cdm.cxl_device_mode ? !cxl_rx_active_sts: 1'b1)
// For DSP wait till the RX deactivated then check the TX deactivation  to request L1/2 (Ack Low power request)
assign cxl_link_pm_l1_req               = cxl_ll_init_crd_done && pm_req_l1 && 
                                          ((b_vlsm_llctrl.s_pl_state_sts inside {IDLE_L1_1, ACTIVE}) ? (cxl_retry_normal ) : 1'b1) &&
                                          (b_cdm.s_cfg_dev_mode ? !cxl_rx_active_sts: 1'b1);

assign cxl_link_pm_l2_req               = cxl_ll_init_crd_done && pm_req_l2 && 
                                          ((b_vlsm_llctrl.s_pl_state_sts inside {ACTIVE}) ? (cxl_retry_normal ) : 1'b1) &&
                                          (b_cdm.s_cfg_dev_mode ? !cxl_rx_active_sts: 1'b1);

assign link_tx_deinit_req               = (b_vlsm_llctrl.s_lp_state_req inside {IDLE_L1_1, L2}) || (b_vlsm_llctrl.s_pl_state_sts inside {IDLE_L1_1, L2})
;

// -------------------------------------------------------------------------------------
// Protocol Decoder Instantiation to be used on the hierarchy level
// -------------------------------------------------------------------------------------
spif_protocol_dec
 u_spif_protocol (
    // Inputs
    .core_clk        ( b_clk.s_core_clk              ),
    .core_rst_n      ( b_clk.s_core_rst_n            ),
    .pl_protocol_vld ( lp_protocol_vld               ),
    .pl_protocol     ( lp_protocol                   ),
    .pl_protocol_fmt ( lp_protocol_fmt               ),
    // Outputs
    .pl_protocol_cfg ( cxl_protocol_cfg              )
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// SPIF Link Layer State Request FSM Instantiation
// -------------------------------------------------------------------------------------
logic   spif_state_reset_req;
assign  spif_state_reset_req =  b_cdm.s_cfg_ll_reset;
spif_state_req
 #(
    .PROTOCOL (1'b1)
) u_lp_state_req (
    // Inputs
    .core_clk        ( b_clk.s_core_clk                ),
    .core_rst_n      ( b_clk.s_core_rst_n              ),
    .pl_protocol_vld ( b_vlsm_llctrl.s_pl_protocol_vld ),
    .pl_protocol     ( b_vlsm_llctrl.s_pl_protocol     ),
    .pl_protocol_fmt ( b_vlsm_llctrl.s_pl_protocol_fmt ),
    .pl_inband_pres  ( b_vlsm_llctrl.s_pl_inband_pres  ),
    .pl_phyinretrain ( b_vlsm_llctrl.s_pl_phyinretrain ),
    .pl_state_sts    ( b_vlsm_llctrl.s_pl_state_sts    ),
    .pl_stall_req    ( b_vlsm_llctrl.s_pl_stall_req    ),
    .lp_pm_l0s_req   ( 1'b0                            ),
    .lp_pm_l1_req    ( cxl_link_pm_l1_req              ),
    .lp_pm_l2_req    ( cxl_link_pm_l2_req              ),
    .lp_retrain_req  ( cxl_lrsm_req_retrain            ),
    .lp_reset_req    ( spif_state_reset_req            ),
    .lp_disable_req  ( 1'b0                            ),
    // Outputs
    .lp_state_req    ( b_vlsm_llctrl.s_lp_state_req    ),
    .lp_protocol_vld ( lp_protocol_vld                 ),
    .lp_protocol     ( lp_protocol                     ),
    .lp_protocol_fmt ( lp_protocol_fmt                 )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Link Initialization Controller Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_link_init
 u_link_init (
    // Input
    .core_clk                 ( b_clk.s_core_clk                       ),
    .core_rst_n               ( b_clk.s_core_rst_n                     ),
    .cfg_init_stall           ( b_cdm.s_cfg_ll_init_stall              ),
    .cfg_crd_stall            ( b_cdm.s_cfg_ll_crd_stall               ),
    .cfg_cxl_version          ( b_cdm.s_cfg_cxl_version                ),
    .cfg_llr_wrap_value       ( b_cdm.s_cfg_llr_wrap_value             ),
    .cfg_rx_rcvd_llr_wrap     ( b_cdm.s_cfg_rx_rcvd_llr_wrap           ),
    .cxl_pcie_flit_mode       ( cxl_protocol_cfg.cxl_pcie_flit_mode    ),
    .cxl_link_enable          ( cxl_link_enable                        ),
    .cxl_vlsm_init_req        ( cxl_link_init_req                      ),
    .cxl_link_crd_ack         ( cxl_link_crd_ack                       ),
    .cxl_rx_rcvd_init_param   ( b_rxdl_llctrl.s_cxl_rx_rcvd_init_param ),
    .cxl_rx_rcvd_retry        ( b_rxdl_llctrl.s_cxl_rx_rcvd_retry      ),
    .cxl_rx_rcvd_non_retry    ( b_rxdl_llctrl.s_cxl_rx_rcvd_non_retry  ),
    .cxl_init_param_sent      ( cxl_init_param_sent                    ),
    // Outputs
    .cxl_init_retry_error     ( b_cdm.s_cxl_init_retry_error           ),
    .cxl_init_multi_error     ( b_cdm.s_cxl_init_multi_error           ),
    .cxl_ll_init_crd_done     ( cxl_ll_init_crd_done                   ),
    .cxl_ll_init_llr_wrap     ( cxl_ll_init_llr_wrap                   ),
    .cxl_ll_init_crd          ( cxl_ll_init_crd                        ),
    .cxl_ll_init_done         ( cxl_ll_init_done                       ),
    .cxl_ll_init_state        ( cxl_ll_init_state                      ),
    .cxl_init_param_req       ( cxl_init_param_req                     ),
    .cxl_init_param_payload   ( cxl_init_param_payload                 )
);


// -------------------------------------------------------------------------------------
// Link Credit Controller Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_link_credit
 u_link_credit (
    // Inputs
    .core_clk                   ( b_clk.s_core_clk                        ),
    .core_rst_n                 ( b_clk.s_core_rst_n                      ),
    .link_layer_clk             ( link_layer_clk_s                        ),
    .cfg_cache_enable           ( cxl_protocol_cfg.cxl_cache_enable       ),
    .cfg_mem_enable             ( cxl_protocol_cfg.cxl_mem_enable         ),
    .cfg_ack_force_threshold    ( b_cdm.s_cfg_ack_force_threshold         ),
    .cfg_ack_flush_timer        ( b_cdm.s_cfg_ack_flush_timer             ),
    .cxl_ll_init_done           ( cxl_ll_init_done                        ),
    .cxl_viral_llcrd_req        ( cxl_viral_llcrd_req                     ),
    .cxl_rbuf_llcrd_req         ( cxl_rbuf_llcrd_req                      ),
    .cxl_init_llcrd_req         ( cxl_ll_init_crd                         ),
    .cxl_llcrd_sent             ( cxl_llcrd_sent                          ),
    .cxl_rx_retryable_flit      ( b_rxdl_llctrl.s_cxl_rx_rcvd_non_retry   ),
    .cxl_tx_full_ack            ( cxl_tx_full_ack                         ),
    .cxl_fgen_ack_timer_rst     ( cxl_fgen_ack_timer_rst                  ),
    .cxl_device_mode            ( b_cdm.s_cfg_dev_mode                    ),
    .cxl_pcie_flit_mode         ( cxl_protocol_cfg.cxl_pcie_flit_mode     ),
    .cxl_256B_tx_crdret         ( cxl_256B_tx_crdret                      ),
    .cxl_256B_rx_crdret         ( b_rxdl_llctrl.s_cxl_rx_256B_crd         ),
    .cxl_rx_data_crd            ( b_rxdl_llctrl.s_cxl_rx_data_crd         ),
    .cxl_rx_rsp_crd             ( b_rxdl_llctrl.s_cxl_rx_rsp_crd          ),
    .cxl_rx_req_crd             ( b_rxdl_llctrl.s_cxl_rx_req_crd          ),
    .cxl_rx_cache_data_valid    ( b_rxdl_llctrl.s_cxl_rx_cache_data_valid ),
    .cxl_rx_cache_req_valid     ( b_rxdl_llctrl.s_cxl_rx_cache_req_valid  ),
    .cxl_rx_cache_rsp_valid     ( b_rxdl_llctrl.s_cxl_rx_cache_rsp_valid  ),
    .cxl_cache_data_crd         ( cxl_cache_data_crd                      ),
    .cxl_cache_req_crd          ( cxl_cache_req_crd                       ),
    .cxl_cache_rsp_crd          ( cxl_cache_rsp_crd                       ),
    .cxl_cache_dhdr_valid       ( b_mux_pack.s_cxl_cache_dhdr_valid       ),
    .cxl_cache_rsp_valid        ( b_mux_pack.s_cxl_cache_rsp_valid        ),
    .cxl_cache_req_valid        ( b_mux_pack.s_cxl_cache_req_valid        ),
    .cfg_rx_cache_req_credits   ( b_cdm.s_cfg_rx_cache_req_credits        ),
    .cfg_rx_cache_rsp_credits   ( b_cdm.s_cfg_rx_cache_rsp_credits        ),
    .cfg_rx_cache_data_credits  ( b_cdm.s_cfg_rx_cache_data_credits       ),
    .cxl_rx_mem_data_valid      ( b_rxdl_llctrl.s_cxl_rx_mem_data_valid   ),
    .cxl_rx_mem_ndr_valid       ( b_rxdl_llctrl.s_cxl_rx_mem_ndr_valid    ),
    .cxl_rx_mem_bi_valid        ( b_rxdl_llctrl.s_cxl_rx_mem_bi_valid     ),
    .cxl_mem_data_crd           ( cxl_mem_data_crd                        ),
    .cxl_mem_req_crd            ( cxl_mem_req_crd                         ),
    .cxl_mem_rsp_crd            ( cxl_mem_rsp_crd                         ),
    .cxl_mem_dr_valid           ( b_mux_pack.s_cxl_mem_dr_valid           ),
    .cxl_mem_ndr_valid          ( b_mux_pack.s_cxl_mem_ndr_valid          ),
    .cxl_mem_bi_valid           ( b_mux_pack.s_cxl_mem_bi_valid           ),
    .cfg_rx_mem_data_credits    ( b_cdm.s_cfg_rx_mem_data_credits         ),
    .cfg_rx_mem_ndr_credits     ( b_cdm.s_cfg_rx_mem_ndr_credits          ),
    .cfg_rx_mem_bi_credits      ( b_cdm.s_cfg_rx_mem_bi_credits           ), 
    // Outputs
    .cxl_ack_cnt_ovflw          ( b_cdm.s_cxl_ack_cnt_ovflw               ),
    .cxl_rsvd_crd_enc_error     ( b_cdm.s_cxl_rsvd_crd_enc_error          ),
    .cxl_force_llcrd_256byte    ( s_cxl_force_llcrd_256byte               ),
    .cxl_ll_crdret_error        ( b_cdm.s_cxl_ll_crdret_error             ),
    .cxl_llcrd_req              ( cxl_llcrd_req                           ),
    .cxl_llcrd_payload          ( cxl_llcrd_payload                       ),
    .cxl_crd_ctrl_init_done     ( cxl_crd_ctrl_init_done                  ),
    .cxl_ack_cnt_flit_ack       ( cxl_hdr_ack_bit                         ),
    .cxl_ack_cnt_full           ( cxl_ack_cnt_full                        ),
    .cxl_ll_cache_data_crd      ( cxl_ll_cache_data_crd                   ),
    .cxl_ll_cache_rsp_crd       ( cxl_ll_cache_rsp_crd                    ),
    .cxl_ll_cache_req_crd       ( cxl_ll_cache_req_crd                    ),
    .cxl_ll_cache_rsp_gnt       ( cxl_ll_cache_rsp_gnt                    ),
    .cxl_ll_cache_req_gnt       ( cxl_ll_cache_req_gnt                    ),
    .cxl_ll_cache_data_gnt      ( cxl_ll_cache_data_gnt                   ),
    .cxl_rx_cache_data_crdret   ( cxl_rx_cache_data_crdret                ),
    .cxl_rx_cache_rsp_crdret    ( cxl_rx_cache_rsp_crdret                 ),
    .cxl_rx_cache_req_crdret    ( cxl_rx_cache_req_crdret                 ),
    .cxl_ll_mem_data_crd        ( cxl_ll_mem_data_crd                     ),
    .cxl_ll_mem_ndr_crd         ( cxl_ll_mem_ndr_crd                      ),
    .cxl_ll_mem_dr_gnt          ( cxl_ll_mem_dr_gnt                       ),
    .cxl_ll_mem_ndr_gnt         ( cxl_ll_mem_ndr_gnt                      ),
    .cxl_rx_mem_data_crdret     ( cxl_rx_mem_data_crdret                  ),
    .cxl_rx_mem_ndr_crdret      ( cxl_rx_mem_ndr_crdret                   ),
    .cxl_rx_mem_bi_crdret       (cxl_rx_mem_bi_crdret                     ),
    .cxl_ll_mem_bi_crd          ( cxl_ll_mem_bi_crd                       ),
    .cxl_ll_mem_bi_gnt          ( cxl_ll_mem_bi_gnt                       ),
    .cxl_crd_arb_256B_crd       ( cxl_hdr_256B_crd                        ),
    .cxl_crd_arb_data_crd       ( cxl_hdr_data_crd                        ),
    .cxl_crd_arb_rsp_crd        ( cxl_hdr_rsp_crd                         ),
    .cxl_crd_arb_req_crd        ( cxl_hdr_req_crd                         )
);


// -------------------------------------------------------------------------------------
// LLCTRL Flit Generator Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_llctrl_fgen
 u_llctrl_fgen (
    // Inputs
    .core_clk                   ( b_clk.s_core_clk                    ),
    .core_rst_n                 ( b_clk.s_core_rst_n                  ),
    .cxl_pcie_flit_mode         ( cxl_protocol_cfg.cxl_pcie_flit_mode ),
    .cxl_llctrl_halt            ( cxl_llctrl_halt                     ),
    .cxl_retryable_flit_ena     ( cxl_retryable_flit_ena              ),
    .cxl_retry_normal           ( cxl_retry_normal                    ),
    .cxl_hdr_ack_bit            ( cxl_ack_cnt_full[3]                 ),
    .cxl_hdr_data_crd           ( cxl_hdr_data_crd                    ),
    .cxl_hdr_rsp_crd            ( cxl_hdr_rsp_crd                     ),
    .cxl_hdr_req_crd            ( cxl_hdr_req_crd                     ),
    .cxl_init_param_req         ( cxl_init_param_req                  ),
    .cxl_init_param_payload     ( cxl_init_param_payload              ),
    .cxl_rbuf_retry_req         ( cxl_rrsm_rbuf_req                   ),
    .cxl_lrsm_retry_req         ( cxl_lrsm_retry_req                  ),
    .cxl_lrsm_retry_payload     ( cxl_lrsm_retry_payload              ),
    .cxl_lrsm_idle_req          ( cxl_lrsm_idle_req                   ),
    .cxl_rrsm_retry_ack         ( cxl_rrsm_retry_ack                  ),
    .cxl_rrsm_retry_payload     ( cxl_rrsm_retry_payload              ),
    .cxl_llcrd_req              ( cxl_llcrd_req                       ),
    .cxl_llcrd_payload          ( cxl_llcrd_payload                   ),
    .cxl_init_param_sent        ( cxl_init_param_sent                 ),
    .cxl_lrsm_retry_req_sent    ( cxl_lrsm_retry_req_sent             ),
    .cxl_rrsm_retry_ack_sent    ( cxl_rrsm_retry_ack_sent             ),
    .cxl_llcrd_sent             ( cxl_llcrd_sent                      ),
    .cxl_llctrl_flit_valid      ( cxl_llctrl_flit_valid               ),
    .cxl_llctrl_flit_sof        ( cxl_llctrl_flit_sof                 ),
    .cxl_llctrl_flit_eof        ( cxl_llctrl_flit_eof                 ),
    .cxl_llctrl_flit            ( cxl_llctrl_flit                     )
); // DWC_cxl_mem_cache_llctrl_fgen


// -------------------------------------------------------------------------------------
// Flit Interface Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_flit_if
 u_flit_if (
    // Inputs
    .core_clk                   ( b_clk.s_core_clk                    ),
    .core_rst_n                 ( b_clk.s_core_rst_n                  ),
    .cxl_device_mode            ( b_cdm.s_cfg_dev_mode                ),
    .cxl_pcie_flit_mode         ( cxl_protocol_cfg.cxl_pcie_flit_mode ),
    .cfg_viral_status           ( b_cdm.s_cfg_viral_status_set        ),
    .cfg_mc_crc_err_inj         ( b_cdm.s_cfg_mc_crc_err_inj          ),
    .cfg_mc_crc_err_inj_cnt     ( b_cdm.s_cfg_mc_crc_err_inj_cnt      ),
    .cfg_mc_crc_err_inj_busy    ( b_cdm.s_cfg_mc_crc_err_inj_busy     ),
    .xplh_arbmux_ctrl_pending   ( xplh_arbmux_ctrl_pending            ),
    .cxl_link_stall_req         ( b_vlsm_llctrl.s_pl_stall_req        ),
    .cxl_retry_normal           ( cxl_retry_normal                    ),
    .cxl_llctrl_flit_valid      ( cxl_llctrl_flit_valid               ),
    .cxl_llctrl_flit_sof        ( cxl_llctrl_flit_sof                 ),
    .cxl_llctrl_flit_eof        ( cxl_llctrl_flit_eof                 ),
    .cxl_llctrl_flit            ( cxl_llctrl_flit                     ),
    .cxl_llctrl_flit_chk        ( cxl_llctrl_flit_chk                 ),
    .cxl_rbuf_retry_req         ( cxl_rrsm_rbuf_req                   ),
    .cxl_rbuf_flit_valid        ( cxl_rbuf_flit_valid                 ),
    .cxl_rbuf_flit              ( cxl_rbuf_flit                       ),
    .cxl_packer_flit_valid      ( cxl_packer_flit_valid               ),
    .cxl_packer_flit            ( cxl_packer_flit_data                ),
    .cxl_packer_flit_chk        ( cxl_packer_flit_data_chk            ),
    .cxl_packer_all_data        ( cxl_packer_flit_adf                 ),
    .cxl_packer_flit_last       ( cxl_packer_flit_last                ),
    .cxl_packer_llctrl_halt     ( cxl_packer_llctrl_halt              ),
    .cxl_packer_idle            ( cxl_packer_idle                     ),
    .cxl_ll_init_done           ( cxl_link_up                         ),
    .cxl_arb_mux_halt           ( b_tx_arbmux_ctrl.s_arb_mux_flit_halt),
    .cxl_ll_numfreebuf          ( cxl_rbuf_numfree                    ),
    .cxl_ll_full_ack            ( cxl_ack_cnt_full                    ),
    .cxl_ll_flit_ack            ( cxl_hdr_ack_bit                     ),
    // Outputs
    .cxl_retryable_flit_ena     ( cxl_retryable_flit_ena              ),
    .cxl_ll_idle                ( cxl_ll_idle                         ),
    .cxl_cache_data_crd         ( cxl_cache_data_crd                  ),
    .cxl_cache_req_crd          ( cxl_cache_req_crd                   ),
    .cxl_cache_rsp_crd          ( cxl_cache_rsp_crd                   ),
    .cxl_mem_data_crd           ( cxl_mem_data_crd                    ),
    .cxl_mem_req_crd            ( cxl_mem_req_crd                     ),
    .cxl_mem_rsp_crd            ( cxl_mem_rsp_crd                     ),
    .cxl_256B_tx_crdret         ( cxl_256B_tx_crdret                  ),
    .cxl_link_stall_ack         ( cxl_link_stall_ack                  ),
    .cxl_viral_llcrd_req        ( cxl_viral_llcrd_req                 ),
    .cxl_fgen_ack_timer_rst     ( cxl_fgen_ack_timer_rst              ),
    .cxl_fgen_full_ack          ( cxl_tx_full_ack                     ),
    .cxl_fgen_retryable_valid   ( cxl_retryable_valid                 ),
    .cxl_fgen_retryable_flit    ( cxl_retryable_flit                  ),
    .cxl_fgen_flit_valid        ( cxl_ll_arb_flit_valid               ),
    .cxl_fgen_flit_sof          ( cxl_ll_arb_flit_sof                 ),
    .cxl_fgen_flit_eof          ( cxl_ll_arb_flit_eof                 ),
    .cxl_fgen_flit_enf          ( cxl_ll_arb_flit_enf                 ),
    .cxl_fgen_flit_retry        ( cxl_ll_arb_flit_retry               ),
    .cxl_fgen_flit              ( cxl_ll_arb_flit                     ),
    .cxl_fgen_flit_err          ( cxl_ll_arb_flit_err                 ),
    .cxl_fgen_flit_chk          ( cxl_ll_arb_flit_chk                 ),
    .cxl_fgen_flit_lp_pri       ( cxl_ll_arb_flit_lp_pri              ),
    .cxl_fgen_packer_data_en    ( cxl_ll_packer_data_en               ),
    .cxl_fgen_packer_halt       ( cxl_ll_packer_halt                  ),
    .cxl_fgen_llctrl_halt       ( cxl_llctrl_halt                     ),
    .cxl_fgen_rbuf_halt         ( cxl_ll_rbuf_halt                    )
);

// -------------------------------------------------------------------------------------
// Flit and Link Layer Clock Generator Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_flit_clk_gen
 u_retry_timer_flit_clk (
    .core_clk           ( b_clk.s_core_clk                    ),
    .core_rst_n         ( b_clk.s_core_rst_n                  ),
    .cxl_mode_enable    ( cxl_protocol_cfg.cxl_mode_enable    ),
    .cxl_pcie_flit_mode ( cxl_protocol_cfg.cxl_pcie_flit_mode ),
    .pl_speedmode       ( b_vlsm_llctrl.s_pl_speedmode        ),
    .pl_linkmode        ( b_vlsm_llctrl.s_pl_linkmode         ),
    .pl_bw_ratio        ( b_vlsm_llctrl.s_pl_bw_ratio         ),
    .pl_state_sts       ( b_vlsm_llctrl.s_pl_state_sts        ),
    .pl_phyinretrain    ( b_vlsm_llctrl.s_pl_phyinretrain     ),
    .flit_clk           ( flit_clk_s                          ),
    .link_layer_clk     ( link_layer_clk_s                    )
);

// -------------------------------------------------------------------------------------
// Link Retry Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_link_retry
 u_link_retry (
    // Inputs
    .core_clk                   ( b_clk.s_core_clk                            ),
    .core_rst_n                 ( b_clk.s_core_rst_n                          ),
    .cfg_max_retry              ( b_cdm.s_cfg_max_retry                       ),
    .cfg_max_reinit             ( b_cdm.s_cfg_max_reinit                      ),
    .cfg_retry_timer            ( b_cdm.s_cfg_retry_timer                     ),
    .cxl_rx_crc_err             ( b_rxdl_llctrl.s_cxl_rx_crc_err              ),
    .cxl_rx_retry_ack           ( b_rxdl_llctrl.s_cxl_rx_retry_ack            ),
    .cxl_rx_retry_ack_empty     ( b_rxdl_llctrl.s_cxl_rx_rcvd_retry_ack_empty ),
    .cxl_rx_ack_num_retry       ( b_rxdl_llctrl.s_cxl_rx_rack_num_retry       ),
    .cxl_rx_req_num_retry       ( b_rxdl_llctrl.s_cxl_rx_req_num_retry        ),
    .cxl_rx_eseq                ( b_rxdl_llctrl.s_cxl_rx_eseq                 ),
    .cxl_rx_retry_req           ( b_rxdl_llctrl.s_cxl_rx_retry_req            ),
    .cxl_rx_rcvd_retryable_flit ( b_rxdl_llctrl.s_cxl_rx_rcvd_non_retry       ),
    .cxl_rx_full_ack            ( b_rxdl_llctrl.s_cxl_rx_full_ack             ),
    .cxl_vlsm_recovery          ( cxl_link_in_retrain                         ),
    .cxl_vlsm_active            ( cxl_link_retrain_exit                       ),
    .cxl_tx_flit_valid          ( cxl_packer_flit_valid                       ),
    .cxl_lrsm_retry_req_sent    ( cxl_lrsm_retry_req_sent                     ),
    .cxl_rrsm_retry_ack_sent    ( cxl_rrsm_retry_ack_sent                     ),
    .cfg_viral_satus            ( b_cdm.s_cfg_viral_status                    ),
    .flit_clk                   ( flit_clk_s                                  ),
    .cxl_retryable_valid        ( cxl_retryable_valid                         ),
    .cxl_retryable_flit         ( cxl_retryable_flit                          ),

    .cxl_llctrl_rbuf_en         ( 1'b1                                        ),
    .cxl_llctrl_rbuf_halt       ( cxl_ll_rbuf_halt                            ),
    .rbuf_ram_rdata             ( b_rbuf_llctrl.s_rbuf_ram_rdata              ),
    .cxl_init_llr_wrap          ( cxl_ll_init_llr_wrap                        ),
    .cxl_packer_halt            ( cxl_ll_packer_halt                          ),
    .ras_dp_err_log             ( ras_dp_err_log_rbuf                         ),
    .ras_dp_uncorr_err          ( ras_dp_uncorr_err_rbuf                      ),
    .ras_dp_err_inj             ( ras_dp_err_inj_tx_dl                        ),
    // Outputs
    .cxl_lrsm_retry_req         ( cxl_lrsm_retry_req                          ),
    .cxl_lrsm_retry_payload     ( cxl_lrsm_retry_payload                      ),
    .cxl_lrsm_idle_req          ( cxl_lrsm_idle_req                           ),
    .cxl_rrsm_retry_ack         ( cxl_rrsm_retry_ack                          ),
    .cxl_rrsm_retry_payload     ( cxl_rrsm_retry_payload                      ),
    .cxl_rrsm_active            ( cxl_rrsm_active                             ),
    .cxl_lrsm_retry_hit         ( cxl_lrsm_retry_hit                          ),
    .cxl_lrsm_reinit_hit        ( cxl_lrsm_reinit_hit                         ),
    .cxl_lrsm_uc_err            ( cxl_lrsm_uc_err                             ),
    .cxl_lrsm_drop_flits        ( cxl_lrsm_drop_flits                         ),
    .cxl_lrsm_req_retrain       ( cxl_lrsm_req_retrain                        ),
    .cxl_lrsm_state             ( cxl_lrsm_state                              ),
    .cxl_rbuf_eseq_ovflw        ( cxl_rbuf_eseq_ovflw                         ),
    .cxl_rbuf_addr              ( cxl_rbuf_addr                               ),
    .cxl_rbuf_addr_par          ( cxl_rbuf_addr_par                           ),
    .cxl_rbuf_en                ( cxl_rbuf_en                                 ),
    .cxl_rbuf_wen               ( cxl_rbuf_wen                                ),
    .cxl_rbuf_wdata             ( cxl_rbuf_wdata                              ),
    .cxl_rbuf_flit_valid        ( cxl_rbuf_flit_valid                         ),
    .cxl_rbuf_flit              ( cxl_rbuf_flit                               ),
    .cxl_rbuf_numfree           ( cxl_rbuf_numfree                            ),
    .cxl_rbuf_consumed          ( cxl_rbuf_consumed                           ),
    .cxl_rbuf_llcrd_req         ( cxl_rbuf_llcrd_req                          ),
    .cxl_rrsm_rbuf_req          ( cxl_rrsm_rbuf_req                           )
); // DWC_cxl_mem_cache_link_retry


// -------------------------------------------------------------------------------------
// Flit Packer Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_packer
 u_link_flit_packer (
    .core_clk               ( b_clk.s_core_clk               ),
    .core_rst_n             ( b_clk.s_core_rst_n             ),
    .cfg_device_mode        ( b_cdm.s_cfg_dev_mode           ),
    .cxl_pcie_flit_mode     ( cxl_protocol_cfg.cxl_pcie_flit_mode),
    .cfg_cache_poison_start ( b_cdm.s_cfg_cache_poison_start ),
    .cfg_cache_poison_busy  ( b_cdm.s_cfg_cache_poison_busy  ),
    .cfg_mem_poison_start   ( b_cdm.s_cfg_mem_poison_start   ),
    .cfg_mem_poison_busy    ( b_cdm.s_cfg_mem_poison_busy    ),
    .b_txtl_host            ( b_txtl_host                    ),
    .b_txtl_dev             ( b_txtl_dev                     ),
    .b_llctrl               ( b_pack_llctrl.slave_ctrl_mp    ),
    .cxl_crd_arb_256B_crd   ( cxl_hdr_256B_crd               ),
    .cxl_packer_force_crd   ( s_packer_force_crd             ),
    .b_pack                 ( b_pack.master_pack_rasdp_mp    )
);


// -------------------------------------------------------------------------------------
// Multistream Data Link RAS Wrapper
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_tx_dl_rasdp_wr_ms
 u_ms_dl_ras_wrapper (     
//input     
      .core_clk                   ( b_clk.s_core_clk                    )
     ,.core_rst_n                 ( b_clk.s_core_rst_n                  )
     ,.cxl_pcie_flit_mode         ( cxl_protocol_cfg.cxl_pcie_flit_mode )
  // Packer RAS DP Generation    
     ,.cxl_packer_flit_data_i     ( b_pack.s_cxl_packer_flit            )     
     ,.cxl_flit_if_data_chk       ( cxl_packer_flit_data_chk            ) 
    // LLCTRL RAS DP Generation   
     ,.cxl_llctrl_flit            ( cxl_llctrl_flit                     ) 
     ,.cxl_llctrl_flit_chk        ( cxl_llctrl_flit_chk                 )  
    // IDE Secure IF RAS Checking 
);

endmodule
