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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #12 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx.sv#12 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Transmitter Top Module 
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_cdmregs_if.svh"
`include "CXL/svif/DWC_cxl_rxdl_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_rbuf_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_app_ch_if.svh"
`include "CXL/svif/DWC_cxl_app_ch_init_if.svh"
`include "CXL/svif/DWC_cxl_txtl_llctrl_if.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"

module DWC_cxl_mem_cache_tx
 import spif_pkg::protocol_cfg_t;
 import spif_pkg::IDLE_L1_1;
 import spif_pkg::L2;
 import DWC_cxl_pkg::*;
 import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 import DWC_pcie_ctl_pkg::ras_dp_err_log_t;

#(
  parameter TP = `TP
)    (
    DWC_cxl_clk_rst_if.slave_mp          b_clk,             // clock and reset interface
    DWC_cxl_cdmregs_if.slave_mp          b_cdm,             // CDM interface
    // -------------------------------------------------------------------------------------
    // CXL Transmitter External Interfaces
    // -------------------------------------------------------------------------------------
    DWC_cxl_rxdl_llctrl_if.slave_mp      b_rxdl_llctrl,  // Receiver link layer interface to link layer control
    spif_if.slave_mp                     b_vlsm_llctrl,  // Link Layer to VLSM SPIF Interface for CXL.cachemem
    spif_if.cfgi_master_mp               b_cfgi_spif,    // CFGI SPIF interface
    DWC_cxl_rbuf_llctrl_if.master_mp     b_rbuf_llctrl,  // Retry Buffer Interface
    output ras_dp_err_log_t              ras_dp_err_log, // Error Logs from CXL TX
    output  [CXL_TX_RAS_UNCORR_NUM-1:0]  ras_dp_uncorr_err, // RASDP Uncorrectable Errors from CXL TX
    input ras_dp_err_inj_t               ras_dp_err_inj, // Error Injection control to RASDP Wrapper
    // -------------------------------------------------------------------------------------
    // CXL Protocol Link Initialization Interfaces
    // -------------------------------------------------------------------------------------
    DWC_cxl_app_ch_init_if.slave_mp      b_app_cache_init,
    DWC_cxl_app_ch_init_if.slave_mp      b_app_mem_init,
    // -------------------------------------------------------------------------------------
    // CXL Message Channel Interfaces
    // -------------------------------------------------------------------------------------
    DWC_cxl_app_ch_if.slave_host_mp      b_app_host_chi, // Application Host Channel Interface
    DWC_cxl_app_ch_if.slave_device_mp    b_app_dev_chi,  // Application Device Channel Interface
    // -------------------------------------------------------------------------------------
    // CXL Transmitter RAM Interfaces
    // -------------------------------------------------------------------------------------
    // -------------------------------------------------------------------------------------
    // Protocol Configuration Structure
    // -------------------------------------------------------------------------------------
    output protocol_cfg_t                cxl_protocol_cfg,    // Protocol Configuration for CXL Controller
    // -------------------------------------------------------------------------------------
    // RASDP Error Injection Interface
    // -------------------------------------------------------------------------------------
    // -------------------------------------------------------------------------------------
    // RASDP Interface
    // -------------------------------------------------------------------------------------
    // -------------------------------------------------------------------------------------
    // RAS Wrapper Interface
    // -------------------------------------------------------------------------------------
    output [7:0]                         cxl_tx_fifo_ovflw_o, // Transmitter Channel Message FIFO Overflow
    // -------------------------------------------------------------------------------------
    // Link Down Interface
    // -------------------------------------------------------------------------------------
    // -------------------------------------------------------------------------------------
    // PM Controller Interface
    // -------------------------------------------------------------------------------------
    output                               link_tx_deinit_req,   // Tx Link deinit for app interface 
    input                                lp_cxl_l1_exit,       // SPIF: Request to CXL.cachemem Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
    input                                lp_cxl_clk_ack,       // SPIF: CXL.cachemem Link Layer acknowledges LogPHY request to remove the clock gating
    input                                lp_cxl_wake_req,      // SPIF: CXL.cachemem Link Layer requests LogPHY to remove the clock gating
    input                                pm_req_l2,            // PM request L2 Entry from PM Controller
    input                                cxl_rx_active_sts     // RX Interface Activation Status
      ,output                              cxl_s2m_data_pis 
      ,output                              cxl_m2s_data_pis 
      ,output                              cxl_h2d_data_pis 
      ,output                              cxl_d2h_data_pis 
);

DWC_cxl_txtl_llctrl_if               b_txtl_host();  // Transaction Layer Interface to Link Layer / RASDP Wrapper
DWC_cxl_txtl_llctrl_if               b_txtl_dev();   // Transaction Layer Interface to Link Layer / RASDP Wrapper
DWC_cxl_txtl_llctrl_if               b_txll_host();  // RASDP Wrapper to Link Layer Interface
DWC_cxl_txtl_llctrl_if               b_txll_dev();   // RASDP Wrapper to Link Layer Interface
DWC_cxl_txtl_llctrl_if               b_txtl_rasdp(); // Transaction Layer - RASDP Wrapper Interface
wire                                 cxl_lp_ack;
wire                                 cxl_ll_idle;    // CXL LL Controller is in Idle state
wire                                 cxl_link_up;    // Indicates that CXL Link is up

localparam CXL_TX_RAS_ERR_LOG_NUM = 1 + 1;

logic [CXL_TX_TL_RAS_UNCORR_NUM-1:0]   ras_dp_uncorr_err_tl; // Uncorrectable Errors from RASDP Wrapper
logic [CXL_TX_LL_RAS_UNCORR_NUM-1:0]   ras_dp_uncorr_err_ll; // Uncorrectable Errors from Link Layer

ras_dp_err_inj_t                       ras_dp_err_inj_s;     // Error injection for CXL TX checkers

ras_dp_err_log_t                       ras_dp_err_log_tl;    // Error Logs from RASDP Wrapper
ras_dp_err_log_t                                  ras_dp_err_log_ll;    // Error Logs from Link Layer
ras_dp_err_log_t [CXL_TX_RAS_ERR_LOG_NUM-1:0]     ras_dp_err_log_arr;   // Error logs from both TL and LL

assign ras_dp_uncorr_err = {ras_dp_uncorr_err_ll , ras_dp_uncorr_err_tl};
assign ras_dp_err_log_arr = {ras_dp_err_log_ll , ras_dp_err_log_tl};

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( CXL_TX_RAS_ERR_LOG_NUM )
) u_cxl_tx_ras_dp_err_mgr (
    .clk                ( b_clk.s_core_clk            ),
    .rst_n              ( b_clk.s_core_rst_n          ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj              ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_s            ),
    .in_ras_dp_err_log  ( ras_dp_err_log_arr          ),
    .out_ras_dp_err_log ( ras_dp_err_log              )
);




// ----------------------------------------------------------------------------
// L1 Entry Request based on the transmit interface Initialization (Activation) state
// ----------------------------------------------------------------------------
logic  chi_pm_req_l1_s;
logic  chi_pm_req_l1_r;

assign chi_pm_req_l1_s = 1'b1 && !b_app_cache_init.s_cxl_init_req && !b_app_cache_init.s_cxl_init_ack 
   && !b_app_mem_init.s_cxl_init_req   && !b_app_mem_init.s_cxl_init_ack ;

delay_n
 #(
    .WD    (1)
) u_delay_pm_req (
    .clk   (b_clk.s_core_clk),
    .rst_n (b_clk.s_core_rst_n),
    .clear (1'b0),
    .din   (chi_pm_req_l1_s),
    .dout  (chi_pm_req_l1_r)
);


logic  pm_req_l1;
assign pm_req_l1 = ( chi_pm_req_l1_r) && !pm_req_l2;
// ----------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL Transmitter Transaction Layer Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_tx_tl
 u_cxl_tx_tl (
    .b_clk                     ( b_clk                                            ),
    .cfg_cxl_cache_capable     ( cxl_protocol_cfg.cxl_cache_enable                ),
    .cfg_cxl_mem_capable       ( cxl_protocol_cfg.cxl_mem_enable                  ),
    .cfg_dev_mode              ( b_cdm.s_cfg_dev_mode                             ),
    .cxl_lp_req                ( link_tx_deinit_req                               ),
    .cxl_lp_ack                ( cxl_lp_ack                                       ),
    .cxl_ll_idle               ( cxl_ll_idle                                      ),
    .core_link_up              ( cxl_link_up                                      )
    ,.b_app_cache_init         ( b_app_cache_init                                 )
    ,.b_app_mem_init           ( b_app_mem_init                                   )
    ,.b_app_host_chi           ( b_app_host_chi                                   )
    ,.b_txtl_host              ( b_txtl_host.master_host_mp                       )
    ,.b_app_dev_chi            ( b_app_dev_chi                                    )
    ,.b_txtl_dev               ( b_txtl_dev.master_dev_mp                         )
    ,.b_txtl_rasdp             ( b_txtl_rasdp.master_rasdp_mp                     )
    ,.cxl_tx_fifo_ovflw_o      ( cxl_tx_fifo_ovflw_o                              )
);

// -------------------------------------------------------------------------------------
// CXL Transmitter RASDP Wrapper Instantiation for MultiStream Architecture
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_tx_rasdp_wr_ms
 u_cxl_tx_rasdp (
     .core_clk            ( b_clk.s_core_clk                      )
    ,.core_rst_n          ( b_clk.s_core_rst_n                    )
    ,.b_txtl_rasdp        ( b_txtl_rasdp.slave_rasdp_mp           )
    ,.cfg_dev_mode        ( b_cdm.s_cfg_dev_mode                  )
    ,.cxl_pcie_flit_mode  ( cxl_protocol_cfg.cxl_pcie_flit_mode   )
    ,.b_txtl_mst_host     ( b_txll_host.master_host_mp            )  // RASDP Wrapper - Link Layer Interface for Host Channels
    ,.b_txtl_slv_host     ( b_txtl_host.slave_host_mp             )  // Transaction Layer - RASDP Wrapper Interface for Host Channels
    ,.b_txtl_mst_dev      ( b_txll_dev.master_dev_mp              )   // RASDP Wrapper - Link Layer Interface for Host Channels
    ,.b_txtl_slv_dev      ( b_txtl_dev.slave_dev_mp               )   // Transaction Layer - RASDP Wrapper Interface for Host Channels
    ,.cxl_s2m_data_pis    ( cxl_s2m_data_pis                      )    
    ,.cxl_m2s_data_pis     ( cxl_m2s_data_pis                     ) 
    ,.cxl_h2d_data_pis     ( cxl_h2d_data_pis                     )
    ,.cxl_d2h_data_pis     ( cxl_d2h_data_pis                     )
    ,.ras_dp_err_log       ( ras_dp_err_log_tl                    )
    ,.ras_dp_uncorr_err    ( ras_dp_uncorr_err_tl                 )
    ,.ras_dp_err_inj       ( ras_dp_err_inj_s                     )
);

// -------------------------------------------------------------------------------------
// CXL Transmitter Link Layer Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_link_ctrl
 u_link_ctrl (
    .b_clk                 ( b_clk                     ),
    .b_cdm                 ( b_cdm                     ),
    .b_rxdl_llctrl         ( b_rxdl_llctrl             ),
    .b_vlsm_llctrl         ( b_vlsm_llctrl             ),
    .b_cfgi_spif           ( b_cfgi_spif               ),
    .b_rbuf_llctrl         ( b_rbuf_llctrl             ),
    .pm_req_l1             ( pm_req_l1                 ),
    .pm_req_l2             ( pm_req_l2                 ),
    .lp_cxl_l1_exit        ( lp_cxl_l1_exit            ),
    .lp_cxl_clk_ack        ( lp_cxl_clk_ack            ),
    .lp_cxl_wake_req       ( lp_cxl_wake_req           ),
    .cxl_rx_active_sts     ( cxl_rx_active_sts         ),
    .cxl_ll_idle           ( cxl_ll_idle               ),
    .link_tx_deinit_req    ( link_tx_deinit_req        ),
    .cxl_link_up           ( cxl_link_up               ),
    .cxl_protocol_cfg      ( cxl_protocol_cfg          )
    ,.ras_dp_err_log            ( ras_dp_err_log_ll         )
    ,.ras_dp_uncorr_err         ( ras_dp_uncorr_err_ll      )
    ,.ras_dp_err_inj            ( ras_dp_err_inj_s          )
    ,.b_txtl_host           ( b_txll_host.slave_host_mp )
    ,.b_txtl_dev            ( b_txll_dev.slave_dev_mp   )
);

endmodule : DWC_cxl_mem_cache_tx
