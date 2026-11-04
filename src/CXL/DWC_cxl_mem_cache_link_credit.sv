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
// ---   $Revision: #9 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_link_credit.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Link Layer Credit Management.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_cdmregs_if.svh"

module DWC_cxl_mem_cache_link_credit
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) 
                                        (
// Inputs ------------------------------------------------------------------------------
    input                                   core_clk,                 // Core clock
    input                                   core_rst_n,               // Core reset
    input                                   link_layer_clk,           // Link Layer Clock for Ack Flush Timer
    input                                   cfg_cache_enable,         // Enable CXL.cache
    input                                   cfg_mem_enable,           // Enable CXL.mem
    input [ACK_CNT_WD-1:0]                  cfg_ack_force_threshold,  // Ack force threshold
    input [ACK_FLUSH_TIMER_WD-1:0]          cfg_ack_flush_timer,      // Ack flush threshold
    input                                   cxl_ll_init_done,         // CXL Link Initialization is complete, enable credit exchange
    input                                   cxl_viral_llcrd_req,      // LLCRD Flit Insertion request in Viral state
    input                                   cxl_rbuf_llcrd_req,       // Retry buffer request to send LLCRD flit
    input                                   cxl_init_llcrd_req,       // Initialization FSM request to send LLCRD flit
    input                                   cxl_llcrd_sent,           // CRD LLCRD flit sent
    input                                   cxl_rx_retryable_flit,    // Received an error free retryable flit
    input [ACK_CNT_WD-1:0]                  cxl_tx_full_ack,          // Full Ack field from transmitted flit
    input                                   cxl_fgen_ack_timer_rst,   // Reset Acknowledge Flash Time
    input                                   cxl_device_mode,          // 0 - Endpoint; 1 - Root Complex Device
    input                                   cxl_pcie_flit_mode,       // CXL 256B Flit Mode
    input CRD_256B_t                        cxl_256B_rx_crdret,       // RX Credit Return in 256B Flit Mode - received 2B CRD field
    input CRD_256B_t                        cxl_256B_tx_crdret,       // TX Decode 256B - transmitted 2B CRD field
    input [CRD_RET_WD-1:0]                  cxl_mem_data_crd,         // TX Decode 68B - CXL.mem Data transmitted credit
    input [CRD_RET_WD-1:0]                  cxl_mem_req_crd,          // TX Decode 68B - CXL.mem Request transmitted credit
    input [CRD_RET_WD-1:0]                  cxl_mem_rsp_crd,          // TX Decode 68B - CXL.mem Response transmitted credit
    input [TX_CRDIF_WIDTH-1:0]              cxl_mem_dr_valid,         // Flit Packer - CXL.mem Data messages packed in the flit
    input [TX_CRDIF_WIDTH-1:0]              cxl_mem_ndr_valid,        // Flit Packer - CXL.mem Request/Response messages packed in the flit
    input  [TX_CRDIF_WIDTH-1:0]             cxl_mem_bi_valid,         // Flit Packer - CXL.mem BI-Snoop/Response packed in the flit
    input [1:0]                             cxl_rx_mem_data_valid,    // Receiver offloaded from mem data queue
    input [MEM_NDR_VALID_WD-1:0]            cxl_rx_mem_ndr_valid,     // Receiver offloaded from mem Request queue
    input [MEM_BI_VALID_WD-1:0]             cxl_rx_mem_bi_valid,      // Number of CXL.mem BI-Snoop/Response messages offloaded from Receive Queue
    input [RX_CREDIT_WD-1:0]                cfg_rx_mem_bi_credits,    // Credit Config - RX CXL.mem BI-Snoop/Response Credits
    input [RX_CREDIT_WD-1:0]                cfg_rx_mem_data_credits,  // Credit Config - RX CXL.mem Data Credits
    input [RX_CREDIT_WD-1:0]                cfg_rx_mem_ndr_credits,   // Credit Config - RX CXL.mem Request/Response Credits
    input [CRD_RET_WD-1:0]                  cxl_cache_data_crd,       // TX Decode 68B - CXL.cache Data transmitted credit
    input [CRD_RET_WD-1:0]                  cxl_cache_req_crd,        // TX Decode 68B - CXL.cache Request transmitted credit
    input [CRD_RET_WD-1:0]                  cxl_cache_rsp_crd,        // TX Decode 68B - CXL.cache Response transmitted credit
    input [TX_CRDIF_WIDTH-1:0]              cxl_cache_dhdr_valid,     // Transmitter sends Mem Data
    input [TX_CRDIF_WIDTH-1:0]              cxl_cache_rsp_valid,      // Transmitter sends Mem Response
    input [TX_CRDIF_WIDTH-1:0]              cxl_cache_req_valid,      // Transmitter sends Mem Request
    input [1:0]                             cxl_rx_cache_data_valid,  // Number of CXL.cache Data messages offloaded from Receive Queue
    input [CACHE_REQ_VALID_WD-1:0]          cxl_rx_cache_req_valid,   // Number of CXL.cache Request messages offloaded from Receive Queue
    input [CACHE_RSP_VALID_WD-1:0]          cxl_rx_cache_rsp_valid,   // Number of CXL.cache Response messages offloaded from Receive Queue
    input [RX_CREDIT_WD-1:0]                cfg_rx_cache_req_credits, // Credit Config - RX CXL.cache Request Credits
    input [RX_CREDIT_WD-1:0]                cfg_rx_cache_rsp_credits, // Credit Config - RX CXL.cache Response Credits
    input [RX_CREDIT_WD-1:0]                cfg_rx_cache_data_credits,// Credit Config - RX CXL.cache Data Credits
    input [FLIT_CRD_WD-1:0]                 cxl_rx_data_crd,          // Received Data Credits
    input [FLIT_CRD_WD-1:0]                 cxl_rx_rsp_crd,           // Received Response Credits
    input [FLIT_CRD_WD-1:0]                 cxl_rx_req_crd,           // Received Request Credits
// Outputs -----------------------------------------------------------------------------
    output                                  cxl_ack_cnt_ovflw,        // Ack Counter Overflow
    output                                  cxl_rsvd_crd_enc_error,   // CXL Reserved Credit Encoding Error
    output                                  cxl_force_llcrd_256byte,   // CXL force CRD
    output [5:0]                            cxl_ll_crdret_error,      // CXL Credit Return Overflow
    output logic                            cxl_llcrd_req,            // CRD requests LLCRD sequence
    output logic [63:0]                     cxl_llcrd_payload,        // CRD requests LLCRD payload
    output logic                            cxl_crd_ctrl_init_done,   // Credit intialization done indication
    output logic                            cxl_ack_cnt_flit_ack,     // When set to 1 Ack bit can be set in the Flit Header
    output logic [ACK_CNT_WD-1:0]           cxl_ack_cnt_full,         // Full Ack Counter
    output logic [TX_CREDIT_WD-1:0]         cxl_ll_cache_data_crd,    // Cache Data Credit for transmitter
    output logic [TX_CREDIT_WD-1:0]         cxl_ll_cache_rsp_crd,     // Cache Response Credit for transmitter
    output logic [TX_CREDIT_WD-1:0]         cxl_ll_cache_req_crd,     // Cache Request Credit for transmitter
    output logic [RX_CREDIT_WD-1:0]         cxl_rx_cache_data_crdret, // Cache Data Accumulated Credit Return
    output logic [RX_CREDIT_WD-1:0]         cxl_rx_cache_req_crdret,  // Cache Request Accumulated Credit Return
    output logic [RX_CREDIT_WD-1:0]         cxl_rx_cache_rsp_crdret,  // Cache Response Accumulated Credit Return
    output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_cache_req_gnt,     // Cache Request Grant
    output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_cache_rsp_gnt,     // Cache Response Grant
    output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_cache_data_gnt,    // Cache Data Grant
    output logic [TX_CREDIT_WD-1:0]         cxl_ll_mem_data_crd,      // Mem Data Credit for transmitter
    output logic [TX_CREDIT_WD-1:0]         cxl_ll_mem_ndr_crd,       // Mem NDR Credit for transmitter
    output logic [RX_CREDIT_WD-1:0]         cxl_rx_mem_data_crdret,   // Mem Data Accumulated Credit Return
    output logic [RX_CREDIT_WD-1:0]         cxl_rx_mem_ndr_crdret,    // Mem Request/Response Accumulated Credit Return
    output logic [RX_CREDIT_WD-1:0]         cxl_rx_mem_bi_crdret,
    output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_mem_dr_gnt,        // Grant MEM DR messages
    output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_mem_ndr_gnt,       // Grand MEM NDR messages
    output logic [TX_CREDIT_WD-1:0]         cxl_ll_mem_bi_crd,     // CXL.mem BI-Snoop/Response credit
    output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_mem_bi_gnt,     // CXL.mem BI-Snoop/Response grant
    output CRD_256B_t                       cxl_crd_arb_256B_crd,     // Flit Formation - 256B Flit RX Credit Return (2B CRD)
    output logic [FLIT_CRD_WD-1:0]          cxl_crd_arb_data_crd,     // Flit Formation - 68B Flit Data Credit Return for Flit Header
    output logic [FLIT_CRD_WD-1:0]          cxl_crd_arb_rsp_crd,      // Flit Formation - 68B Flit Response Credit Return for Flit Header
    output logic [FLIT_CRD_WD-1:0]          cxl_crd_arb_req_crd       // Flit Formation - 68B Flit Request Credit Return for Flit Header
);

// Logic Declarations
logic [FLIT_CRD_WD-1:0]       s_cxl_ll_cache_data_crdret; // Credit Arbiter - 68B Flit RX Credit Return for CXL.cache Data
logic [FLIT_CRD_WD-1:0]       s_cxl_ll_cache_req_crdret;  // Credit Arbiter - 68B Flit RX Credit Return for CXL.cache Request
logic [FLIT_CRD_WD-1:0]       s_cxl_ll_cache_rsp_crdret;  // Credit Arbiter - 68B Flit RX Credit Return for CXL.cache Response
CRD_256B_t                    s_cxl_ll_cache_256B_crdret; // Credit Arbiter - 256B Flit RX Credit Return for CXL.cache
logic [FLIT_CRD_WD-1:0]       s_cxl_ll_mem_data_crdret;   // Credit Arbiter - 68B Flit RX Credit Return for CXL.mem Data
logic [FLIT_CRD_WD-1:0]       s_cxl_ll_mem_req_crdret;    // Credit Arbiter - 68B Flit RX Credit Return for CXL.mem Request
logic [FLIT_CRD_WD-1:0]       s_cxl_ll_mem_rsp_crdret;    // Credit Arbiter - 68B Flit RX Credit Return for CXL.mem Response
CRD_256B_t                    s_cxl_ll_mem_256B_crdret;   // Credit Arbiter - 256B Flit RX Credit Return for CXL.mem

logic                         s_arb_crdret_empty;         // Indicates that there are no credits to return
logic                         s_cxl_ll_cache_crdret_done; // Link Credit FSM - CXL.cache Credit Initialization Done signal
logic                         s_cxl_ll_mem_crdret_done;   // Link Credit FSM - CXL.mem Credit Initialization Done signal

// Return credit empty
assign s_arb_crdret_empty         =  (cxl_pcie_flit_mode)? ~|cxl_crd_arb_256B_crd : ~|(cxl_crd_arb_req_crd[CRD_RET_WD-1:0] | cxl_crd_arb_rsp_crd[CRD_RET_WD-1:0] | cxl_crd_arb_data_crd[CRD_RET_WD-1:0]);

// -------------------------------------------------------------------------------------
// Credit Control
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_crd_ctrl
 u_crd_ctrl (
    // Inputs
    .core_clk                   ( core_clk                    ),
    .core_rst_n                 ( core_rst_n                  ),
    .cfg_cache_enable           ( cfg_cache_enable            ),
    .cfg_mem_enable             ( cfg_mem_enable              ),
    .cxl_ll_full_ack            ( cxl_ack_cnt_full            ),
    .cxl_ack_cnt_llcrd_req      ( cxl_ack_cnt_force_llcrd     ),
    .cxl_viral_llcrd_req        ( cxl_viral_llcrd_req         ),
    .cxl_rbuf_llcrd_req         ( cxl_rbuf_llcrd_req          ),
    .cxl_init_llcrd_req         ( cxl_init_llcrd_req          ),
    .cxl_cache_crdret_done      ( s_cxl_ll_cache_crdret_done  ),
    .cxl_mem_crdret_done        ( s_cxl_ll_mem_crdret_done    ),
    .cxl_llcrd_sent             ( cxl_llcrd_sent              ),
    // Outputs
    .cxl_llcrd_req              ( cxl_llcrd_req               ),
    .cxl_llcrd_payload          ( cxl_llcrd_payload           ),
    .cxl_crd_ctrl_init_cache    ( cxl_crd_ctrl_init_cache     ),
    .cxl_crd_ctrl_init_mem      ( cxl_crd_ctrl_init_mem       ),
    .cxl_crd_ctrl_init_done     ( cxl_crd_ctrl_init_done      )
); // u_crd_ctrl

// -------------------------------------------------------------------------------------
// Ack Counter
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_ack_cnt
 u_ack_cnt (
    // Inputs
    .core_clk                   ( core_clk                    ),
    .core_rst_n                 ( core_rst_n                  ),
    .link_layer_clk             ( link_layer_clk              ),
    .cxl_rx_retryable_flit      ( cxl_rx_retryable_flit       ),
    .cxl_flit_full_ack          ( cxl_tx_full_ack             ),
    .cxl_arb_crdret_empty       ( s_arb_crdret_empty          ),
    .cxl_fgen_ack_timer_rst     ( cxl_fgen_ack_timer_rst      ),
    .cfg_ack_force_threshold    ( cfg_ack_force_threshold     ),
    .cfg_ack_flush_timer        ( cfg_ack_flush_timer         ),
    .cfg_en_ack_flush_timer     ( cxl_ll_init_done            ),
    // Outputs
    .cxl_ack_cnt_ovflw          ( cxl_ack_cnt_ovflw           ),
    .cxl_ack_cnt_full           ( cxl_ack_cnt_full            ),
    .cxl_ack_cnt_flit_ack       ( cxl_ack_cnt_flit_ack        ),
    .cxl_ack_cnt_force_llcrd    ( cxl_ack_cnt_force_llcrd     )
); // u_ack_cnt

assign cxl_force_llcrd_256byte = cxl_ack_cnt_force_llcrd;
// -------------------------------------------------------------------------------------
// Credit Arbitration
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_crd_arb
 u_crd_arb (
    // Inputs
    .core_clk                   ( core_clk                    ),
    .core_rst_n                 ( core_rst_n                  ),
    .cxl_pcie_flit_mode         ( cxl_pcie_flit_mode          ),
    .cxl_ll_init_done           ( cxl_ll_init_done            ),
    .cxl_init_mem_crd           ( cxl_crd_ctrl_init_mem       ),
    .cxl_init_cache_crd         ( cxl_crd_ctrl_init_cache     ),
    .cfg_cache_enable           ( cfg_cache_enable            ),
    .cfg_mem_enable             ( cfg_mem_enable              ),
    .cxl_cache_data_crdret      ( s_cxl_ll_cache_data_crdret  ),
    .cxl_cache_rsp_crdret       ( s_cxl_ll_cache_rsp_crdret   ),
    .cxl_cache_req_crdret       ( s_cxl_ll_cache_req_crdret   ),
    .cxl_cache_256B_crdret      ( s_cxl_ll_cache_256B_crdret  ),
    .cxl_mem_data_crdret        ( s_cxl_ll_mem_data_crdret    ),
    .cxl_mem_req_crdret         ( s_cxl_ll_mem_req_crdret     ),
    .cxl_mem_rsp_crdret         ( s_cxl_ll_mem_rsp_crdret     ),
    .cxl_mem_256B_crdret        ( s_cxl_ll_mem_256B_crdret    ),
    // Outputs
    .cxl_crd_arb_256B_crd       ( cxl_crd_arb_256B_crd        ),
    .cxl_crd_arb_data_crd       ( cxl_crd_arb_data_crd        ),
    .cxl_crd_arb_rsp_crd        ( cxl_crd_arb_rsp_crd         ),
    .cxl_crd_arb_req_crd        ( cxl_crd_arb_req_crd         )
); // u_crd_arb

// -------------------------------------------------------------------------------------
// Receiver Credit Tracking and Return
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_crdret
 u_rx_crd (
    // Inputs
    .core_clk                   ( core_clk                    ),
    .core_rst_n                 ( core_rst_n                  ),
    .cxl_device_mode            ( cxl_device_mode             ),
    .cxl_pcie_flit_mode         ( cxl_pcie_flit_mode          ),
    .cxl_256B_tx_crdret         ( cxl_256B_tx_crdret          ),
    .cfg_mem_enable             ( cfg_mem_enable),
    .cfg_rx_mem_data_credits    ( cfg_rx_mem_data_credits     ),
    .cfg_rx_mem_ndr_credits     ( cfg_rx_mem_ndr_credits      ),
    .cxl_mem_data_crd           ( cxl_mem_data_crd            ),
    .cxl_mem_req_crd            ( cxl_mem_req_crd             ),
    .cxl_mem_rsp_crd            ( cxl_mem_rsp_crd             ),
    .cxl_rx_mem_data_valid      ( cxl_rx_mem_data_valid       ),
    .cxl_rx_mem_ndr_valid       ( cxl_rx_mem_ndr_valid        ),
    .cxl_rx_mem_bi_valid        ( cxl_rx_mem_bi_valid         ),
    .cfg_rx_mem_bi_credits      ( cfg_rx_mem_bi_credits       ),
    .cfg_cache_enable           ( cfg_cache_enable            ),
    .cfg_rx_cache_req_credits   ( cfg_rx_cache_req_credits    ),
    .cfg_rx_cache_rsp_credits   ( cfg_rx_cache_rsp_credits    ),
    .cfg_rx_cache_data_credits  ( cfg_rx_cache_data_credits   ),
    .cxl_cache_data_crd         ( cxl_cache_data_crd          ),
    .cxl_cache_req_crd          ( cxl_cache_req_crd           ),
    .cxl_cache_rsp_crd          ( cxl_cache_rsp_crd           ),
    .cxl_rx_cache_data_valid    ( cxl_rx_cache_data_valid     ),
    .cxl_rx_cache_req_valid     ( cxl_rx_cache_req_valid      ),
    .cxl_rx_cache_rsp_valid     ( cxl_rx_cache_rsp_valid      ),
    .cxl_ll_init_done           ( cxl_ll_init_done            ),
    // Outputs
    .cxl_rx_cache_data_crdret   ( cxl_rx_cache_data_crdret    ),
    .cxl_rx_cache_req_crdret    ( cxl_rx_cache_req_crdret     ),
    .cxl_rx_cache_rsp_crdret    ( cxl_rx_cache_rsp_crdret     ),
    .cxl_ll_cache_data_crdret   ( s_cxl_ll_cache_data_crdret  ),
    .cxl_ll_cache_req_crdret    ( s_cxl_ll_cache_req_crdret   ),
    .cxl_ll_cache_rsp_crdret    ( s_cxl_ll_cache_rsp_crdret   ),
    .cxl_ll_cache_256B_crdret   ( s_cxl_ll_cache_256B_crdret  ),
    .cxl_ll_cache_crdret_done   ( s_cxl_ll_cache_crdret_done  ),
    .cxl_rx_mem_data_crdret     ( cxl_rx_mem_data_crdret      ),
    .cxl_rx_mem_ndr_crdret      ( cxl_rx_mem_ndr_crdret       ),
    .cxl_rx_mem_bi_crdret       ( cxl_rx_mem_bi_crdret        ),
    .cxl_ll_mem_data_crdret     ( s_cxl_ll_mem_data_crdret    ),
    .cxl_ll_mem_req_crdret      ( s_cxl_ll_mem_req_crdret     ),
    .cxl_ll_mem_rsp_crdret      ( s_cxl_ll_mem_rsp_crdret     ),
    .cxl_ll_mem_256B_crdret     ( s_cxl_ll_mem_256B_crdret    ),
    .cxl_ll_mem_crdret_done     ( s_cxl_ll_mem_crdret_done    ),
    .cxl_ll_crdret_error        ( cxl_ll_crdret_error         )
); // u_rx_crd

// -------------------------------------------------------------------------------------
// Transmitter Credit Tracking
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_fc
 u_tx_crd (
    // Inputs
     .core_clk                   ( core_clk                    )
    ,.core_rst_n                 ( core_rst_n                  )
    ,.cxl_device_mode            ( cxl_device_mode             )
    ,.cxl_pcie_flit_mode         ( cxl_pcie_flit_mode          )
    ,.cxl_256B_rx_crdret         ( cxl_256B_rx_crdret          )
    ,.cfg_cache_enable           ( cfg_cache_enable            )
    ,.cxl_cache_data_valid       ( cxl_cache_dhdr_valid        )
    ,.cxl_cache_rsp_valid        ( cxl_cache_rsp_valid         )
    ,.cxl_cache_req_valid        ( cxl_cache_req_valid         )
    ,.cfg_mem_enable             ( cfg_mem_enable              )
    ,.cxl_mem_data_valid         ( cxl_mem_dr_valid            )
    ,.cxl_mem_ndr_valid          ( cxl_mem_ndr_valid           )
    ,.cxl_mem_bi_valid           ( cxl_mem_bi_valid            )
    ,.cxl_rx_data_crd            ( cxl_rx_data_crd             )
    ,.cxl_rx_rsp_crd             ( cxl_rx_rsp_crd              )
    ,.cxl_rx_req_crd             ( cxl_rx_req_crd              )
    // Outputs
    ,.rsvd_crd_enc_error         ( cxl_rsvd_crd_enc_error      )
    ,.cxl_ll_cache_data_crd      ( cxl_ll_cache_data_crd       )
    ,.cxl_ll_cache_rsp_crd       ( cxl_ll_cache_rsp_crd        )
    ,.cxl_ll_cache_req_crd       ( cxl_ll_cache_req_crd        )
    ,.cxl_ll_cache_rsp_gnt       ( cxl_ll_cache_rsp_gnt        )
    ,.cxl_ll_cache_req_gnt       ( cxl_ll_cache_req_gnt        )
    ,.cxl_ll_cache_data_gnt      ( cxl_ll_cache_data_gnt       )
    ,.cxl_ll_mem_data_crd        ( cxl_ll_mem_data_crd         )
    ,.cxl_ll_mem_ndr_crd         ( cxl_ll_mem_ndr_crd          )
    ,.cxl_ll_mem_data_gnt        ( cxl_ll_mem_dr_gnt           )
    ,.cxl_ll_mem_ndr_gnt         ( cxl_ll_mem_ndr_gnt          )
    ,.cxl_ll_mem_bi_crd          ( cxl_ll_mem_bi_crd           )
    ,.cxl_ll_mem_bi_gnt          ( cxl_ll_mem_bi_gnt           )
); // u_tx_crd

endmodule
