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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #7 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_link_retry.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Contains RRSM LRSM and Retry Buffer
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_mem_cache_link_retry
    import DWC_cxl_pkg::*;
    import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
    import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
#(
    parameter TP = `TP
)(
// Inputs ------------------------------------------------------------------------------
    input                                 core_clk,                   // Core clock
    input                                 core_rst_n,                 // Core reset
    input [(MAX_RETRY_WD - 1) : 0]        cfg_max_retry,              // Maximum number of retries before triggering a retrain
    input [(MAX_REINIT_WD - 1) : 0]       cfg_max_reinit,             // Maximum number of PHY retrains before triggering abort of retry
    input [(RETRY_TIMER_WD - 1) : 0]      cfg_retry_timer,            // Retry timer target value
    input                                 cfg_viral_satus,            // Viral indication
    input                                 cxl_rx_crc_err,             // CRC error received
    input                                 cxl_rx_retry_ack,           // Retry.Ack received
    input                                 cxl_rx_retry_ack_empty,     // Empty bit indicates that the LLR contains no valid data
    input                                 cxl_vlsm_recovery,          // VLSM is in Recovery
    input                                 cxl_vlsm_active,            // VLSM active
    input                                 cxl_tx_flit_valid,          // Transmitter sends a flit
    input                                 cxl_packer_halt,            // Packer halt 
    input                                 cxl_lrsm_retry_req_sent,    // LRSM Retry.Req sent
    input                                 cxl_rrsm_retry_ack_sent,    // RRSM Retry.Ack sent
    input [(MAX_RETRY_WD - 1) : 0]        cxl_rx_req_num_retry,       // Echo the NUM_RETRY value from the Retry.Req
    input [(MAX_RETRY_WD - 1) : 0]        cxl_rx_ack_num_retry,       // Num Retry Field from the Retry.Ack flit
    input [(ESEQ_WD - 1) : 0]             cxl_rx_eseq,                // Echo the ESEQ value from the Retry.Req
    input                                 cxl_rx_retry_req,           // Received Retry Request
    input                                 cxl_rx_rcvd_retryable_flit, // Received a retryable Flit
    input                                 flit_clk                 ,  // Flit Clock
    input [(CXL_DATA_WD - 1) : 0]         cxl_retryable_flit,         // Retryable Flit for transmission

    input                                 cxl_retryable_valid,        // Retryable Flit Valid
    input                                 cxl_llctrl_rbuf_en,         // Enable Retry Buffer
    input                                 cxl_llctrl_rbuf_halt,       // Halt Flit transmission from the retry buffer
    input [(RBUF_DATA_WD - 1) : 0]        rbuf_ram_rdata,             // Data Read Back from Retry Buffer
    input [(ACK_CNT_WD - 1) : 0]          cxl_rx_full_ack,            // Full Ack Count from the receiver
    input [(ESEQ_WD - 1) : 0]             cxl_init_llr_wrap,          // Wrap around value for the ESEQ counter
    output ras_dp_err_log_t               ras_dp_err_log,             // Error Logs from RASDP instances
    output [CXL_RBUF_RAS_UNCORR_NUM-1:0]  ras_dp_uncorr_err,          // RASDP Errors to trigger Viral
    input  ras_dp_err_inj_t               ras_dp_err_inj,
// Outputs -----------------------------------------------------------------------------
    output logic                          cxl_lrsm_retry_req,         // LRSM requests Retry.Req sequence
    output logic [63:0]                   cxl_lrsm_retry_payload,     // LRSM requests Retry.Req payload
    output logic                          cxl_lrsm_idle_req,          // LRSM requests Retry.Idle flit
    output logic                          cxl_rrsm_retry_ack,         // RRSM requests Retry.Ack sequence
    output logic [63:0]                   cxl_rrsm_retry_payload,     // RRSM requests Retry.Ack payload
    output logic                          cxl_rrsm_active,            // RRSM in the active state
    output logic                          cxl_lrsm_retry_hit,         // LRSM Retry Threshold Hit
    output logic                          cxl_lrsm_reinit_hit,        // LRSM Reinit Threshold Hit
    output logic                          cxl_lrsm_uc_err,            // LRSM error conditions either LRSM Abort or unexpected Retry.Ack 
    output logic                          cxl_lrsm_drop_flits,        // LRSM is active this means all received non LLCTRL retry flits must be discarded
    output logic                          cxl_lrsm_req_retrain,       // LRSM requests a transition to Recovery
    output lrsm_state_e                   cxl_lrsm_state,             // LRSM State
    output logic                          cxl_rbuf_eseq_ovflw,        // Retry buffer ESEQ Overflow
    output logic [(RBUF_ADD_WD - 1) : 0]  cxl_rbuf_addr,              // Retry Buffer Address
    output logic                          cxl_rbuf_addr_par,          // Retry buffer address Parity
    output logic                          cxl_rbuf_en,                // Retry Buffer Enable
    output logic                          cxl_rbuf_wen,               // Retry Buffer Write Enable
    output logic [(RBUF_DATA_WD - 1) : 0] cxl_rbuf_wdata,             // Retry Buffer Write Data
    output logic                          cxl_rbuf_flit_valid,        // Flit from the retry buffer
    output logic [(CXL_DATA_WD - 1) : 0]  cxl_rbuf_flit,           // Flit from the retry buffer
    output logic [(RBUF_ADD_WD - 1) : 0]  cxl_rbuf_numfree,           // Retry Buffer free spaces
    output logic [(RBUF_ADD_WD - 1) : 0]  cxl_rbuf_consumed,          // Spaces consumed in the Retry Buffer
    output logic                          cxl_rbuf_llcrd_req,         // NumFreeBuff is 2 so request LLCRD flit injections
    output logic                          cxl_rrsm_rbuf_req           // Retry Request from RRSM
);

// Declarations
logic [(RBUF_ADD_WD - 1) : 0]            cxl_rbuf_wr_ptr;       // RBUF - Write Pointer
logic                                    cxl_rbuf_retry_done;   // RBUF - Replay is complete
logic [(ESEQ_WD - 1) : 0]                cxl_rbuf_eseq;         // RBUF - ESEQ to be sent with Retry.Req
logic                                    cxl_lrsm_inc_eseq;     // LRSM - Increment ESEQ number in RBUF
logic                                    rbuf_empty_s;          // RBUF is empty (not entries consumed)
logic                                    rrsm_normal_s;         // RRSM is in NORMAL state
logic                                    cxl_lrsm_drop_flits_s; // drop incoming flits on CXL RX path
logic                                    cxl_vlsm_recovery_s;   // VLSM recovery request shifted by CXL_IDE_RX_FLIT_PRED_LATENCY cycle if IDE is enabled

assign cxl_rbuf_llcrd_req   = (cxl_rbuf_numfree == 8'h02);
assign rbuf_empty_s         = (cxl_rbuf_consumed == {RBUF_ADD_WD{1'b0}});
assign rrsm_normal_s        = !cxl_rrsm_active;
// request from RX path to drop the incoming flits in case of LRSM is not in Normal state or when VLSM requests recovery regardless LRSM state
assign cxl_lrsm_drop_flits  = cxl_lrsm_drop_flits_s ;

assign cxl_vlsm_recovery_s   =  cxl_vlsm_recovery;

// -------------------------------------------------------------------------------------
// LRSM Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_lrsm
 u_lrsm (
  // Inputs
  .core_clk                ( core_clk                   ),
  .core_rst_n              ( core_rst_n                 ),
  .cfg_max_retry           ( cfg_max_retry              ),
  .cfg_max_reinit          ( cfg_max_reinit             ),
  .cfg_retry_timer         ( cfg_retry_timer            ),
  .cxl_rx_retryable_flit   ( cxl_rx_rcvd_retryable_flit ),
  .cxl_rx_crc_err          ( cxl_rx_crc_err             ),
  .cxl_rx_retry_ack        ( cxl_rx_retry_ack           ),
  .cxl_rx_retry_ack_empty  ( cxl_rx_retry_ack_empty     ),
  .cxl_rx_ack_num_retry    ( cxl_rx_ack_num_retry       ),
  .cxl_vlsm_recovery       ( cxl_vlsm_recovery_s        ),
  .cxl_vlsm_active         ( cxl_vlsm_active            ),
  .cxl_tx_flit_valid       ( cxl_tx_flit_valid          ),
  .cxl_rbuf_eseq           ( cxl_rbuf_eseq              ),
  .cxl_packer_halt         ( cxl_packer_halt            ),
  .cxl_lrsm_retry_req_sent ( cxl_lrsm_retry_req_sent    ),
  .flit_clk                ( flit_clk                   ),
  // Outputs
  .cxl_lrsm_retry_req      ( cxl_lrsm_retry_req         ),
  .cxl_lrsm_retry_payload  ( cxl_lrsm_retry_payload     ),
  .cxl_lrsm_idle_req       ( cxl_lrsm_idle_req          ),
  .cxl_lrsm_retry_hit      ( cxl_lrsm_retry_hit         ),
  .cxl_lrsm_reinit_hit     ( cxl_lrsm_reinit_hit        ),
  .cxl_lrsm_uc_err         ( cxl_lrsm_uc_err            ),
  .cxl_lrsm_drop_flits     ( cxl_lrsm_drop_flits_s      ),
  .cxl_lrsm_req_retrain    ( cxl_lrsm_req_retrain       ),
  .cxl_lrsm_inc_eseq       ( cxl_lrsm_inc_eseq          ),
  .cxl_lrsm_state          ( cxl_lrsm_state             )
);

// -------------------------------------------------------------------------------------
// RRSM Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rrsm
 u_rrsm (
  // Inputs
  .core_clk                ( core_clk                   ),
  .core_rst_n              ( core_rst_n                 ),
  .cfg_viral_satus         ( cfg_viral_satus            ),
  .cxl_rrsm_retry_ack_sent ( cxl_rrsm_retry_ack_sent    ),
  .cxl_rx_retry_req        ( cxl_rx_retry_req           ),
  .cxl_vlsm_recovery       ( cxl_vlsm_recovery          ),
  .cxl_rbuf_retry_done     ( cxl_rbuf_retry_done        ),
  .cxl_rbuf_empty          ( rbuf_empty_s               ),
  .cxl_rbuf_wr_ptr         ( cxl_rbuf_wr_ptr            ),
  .cxl_rbuf_nfree          ( cxl_rbuf_numfree           ),
  .cxl_rx_req_num_retry    ( cxl_rx_req_num_retry       ),
  .cxl_rx_eseq             ( cxl_rx_eseq                ),
  // Outputs
  .cxl_rrsm_active         ( cxl_rrsm_active            ),
  .cxl_rrsm_rbuf_req       ( cxl_rrsm_rbuf_req          ),
  .cxl_rrsm_retry_ack      ( cxl_rrsm_retry_ack         ),
  .cxl_rrsm_retry_payload  ( cxl_rrsm_retry_payload     )
);

// -------------------------------------------------------------------------------------
// Retry Buffer Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rbuf
 u_rbuf (
  // Inputs
  .core_clk                ( core_clk                   ),
  .core_rst_n              ( core_rst_n                 ),
  .cxl_retryable_flit      ( cxl_retryable_flit         ),
  .cxl_retryable_valid     ( cxl_retryable_valid        ),
  .cxl_llctrl_rbuf_en      ( cxl_llctrl_rbuf_en         ),
  .cxl_llctrl_rbuf_halt    ( cxl_llctrl_rbuf_halt       ),
  .cxl_rrsm_retry_normal   ( rrsm_normal_s              ),
  .cxl_rx_retry_req        ( cxl_rx_retry_req           ),
  .cxl_rx_eseq             ( cxl_rx_eseq                ),
  .cxl_init_llr_wrap       ( cxl_init_llr_wrap          ),
  .cxl_rx_full_ack         ( cxl_rx_full_ack            ),
  .cxl_rrsm_retry_req      ( cxl_rrsm_rbuf_req          ),
  .cxl_lrsm_inc_eseq       ( cxl_lrsm_inc_eseq          ),
  .rbuf_ram_rdata          ( rbuf_ram_rdata             ),
  .ras_dp_err_log          ( ras_dp_err_log             ),
  .ras_dp_uncorr_err       ( ras_dp_uncorr_err          ),
  .ras_dp_err_inj          ( ras_dp_err_inj             ),
  // Outputs
  .cxl_rbuf_eseq_ovflw     ( cxl_rbuf_eseq_ovflw        ),
  .cxl_rbuf_addr           ( cxl_rbuf_addr              ),
  .cxl_rbuf_addr_par       ( cxl_rbuf_addr_par          ),
  .cxl_rbuf_wr_ptr         ( cxl_rbuf_wr_ptr            ),
  .cxl_rbuf_en             ( cxl_rbuf_en                ),
  .cxl_rbuf_wen            ( cxl_rbuf_wen               ),
  .cxl_rbuf_wdata          ( cxl_rbuf_wdata             ),
  .cxl_rbuf_flit_valid     ( cxl_rbuf_flit_valid        ),
  .cxl_rbuf_flit           ( cxl_rbuf_flit              ),

  .cxl_rbuf_retry_done     ( cxl_rbuf_retry_done        ),
  .cxl_rbuf_numfree        ( cxl_rbuf_numfree           ),
  .cxl_rbuf_consumed       ( cxl_rbuf_consumed          ),
  .cxl_rbuf_eseq           ( cxl_rbuf_eseq              )
);



endmodule
