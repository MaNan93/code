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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_crdret.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Credit Return Counters used to return credit to the remote partner based
// on resources available in the local receive queues.
// Counters are initialized based on Queue sizes.
// Counters decrement by the amount of credit that is returned in a given flit.
// Counters increment when messages are offloaded from the receive queues.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_crdret
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) 
                                   (
// Inputs ------------------------------------------------------------------------------
    input                                 core_clk,                  // Core clock
    input                                 core_rst_n,                // Core reste
    input                                 cxl_device_mode,           // 0 - Endpoint; 1 - Root Complex Device
    input                                 cxl_pcie_flit_mode,        // CXL 256B Flit Mode
    input CRD_256B_t                      cxl_256B_tx_crdret,        // TX Decode 256B - transmitted 2B CRD field
    input                                 cfg_mem_enable,            // Enable CXL.mem
    input [RX_CREDIT_WD-1:0]              cfg_rx_mem_data_credits,   // Credit Config - RX CXL.mem Data Credits
    input [RX_CREDIT_WD-1:0]              cfg_rx_mem_ndr_credits,    // Credit Config - RX CXL.mem Request/Response Credits
    input [RX_CREDIT_WD-1:0]              cfg_rx_mem_bi_credits,     // Credit Config - RX CXL.mem BI-Snoop/Response Credits
    input [CRD_RET_WD-1:0]                cxl_mem_data_crd,          // TX Decode 68B - CXL.mem Data transmitted credit
    input [CRD_RET_WD-1:0]                cxl_mem_req_crd,           // TX Decode 68B - CXL.mem Request transmitted credit
    input [CRD_RET_WD-1:0]                cxl_mem_rsp_crd,           // TX Decode 68B - CXL.mem Response transmitted credit
    input [MEM_BI_VALID_WD-1:0]           cxl_rx_mem_bi_valid,       // RX Link Layer - Number of CXL.mem BI-Snoop/Response messages offloaded from Receive Queue
    input [1:0]                           cxl_rx_mem_data_valid,     // RX Link Layer - Number of CXL.mem Data messages offloaded from Receive Queue
    input [MEM_NDR_VALID_WD-1:0]          cxl_rx_mem_ndr_valid,      // RX Link Layer - Number of CXL.mem Request or Response messages offloaded from Receive Queue depending on the device type
    input                                 cfg_cache_enable,          // Enable CXL.cache
    input [RX_CREDIT_WD-1:0]              cfg_rx_cache_req_credits,  // Credit Config - RX CXL.cache Request Credits
    input [RX_CREDIT_WD-1:0]              cfg_rx_cache_rsp_credits,  // Credit Config - RX CXL.cache Response Credits
    input [RX_CREDIT_WD-1:0]              cfg_rx_cache_data_credits, // Credit Config - RX CXL.cache Data Credits
    input [CRD_RET_WD-1:0]                cxl_cache_data_crd,        // TX Decode 68B - CXL.cache Data transmitted credit
    input [CRD_RET_WD-1:0]                cxl_cache_req_crd,         // TX Decode 68B - CXL.cache Request transmitted credit
    input [CRD_RET_WD-1:0]                cxl_cache_rsp_crd,         // TX Decode 68B - CXL.cache Response transmitted credit
    input [1:0]                           cxl_rx_cache_data_valid,   // RX Link Layer - Number of CXL.cache Data messages offloaded from Receive Queue
    input [CACHE_REQ_VALID_WD-1:0]        cxl_rx_cache_req_valid,    // RX Link Layer - Number of CXL.cache Request messages offloaded from Receive Queue
    input [CACHE_RSP_VALID_WD-1:0]        cxl_rx_cache_rsp_valid,    // RX Link Layer - Number of CXL.cache Response messages offloaded from Receive Queue
    input                                 cxl_ll_init_done,          // Link Init FSM - CXL Link Initialization is complete, enable credit exchange
// Outputs -----------------------------------------------------------------------------
    output [5:0]                          cxl_ll_crdret_error        // RAS - CXL Credit Return Overflow
    ,
    output logic [RX_CREDIT_WD-1:0]       cxl_rx_cache_data_crdret,  // Status Register - CXL.cache Data Accumulated Credit Return
    output logic [RX_CREDIT_WD-1:0]       cxl_rx_cache_req_crdret,   // Status Register - CXL.cache Request Accumulated Credit Return
    output logic [RX_CREDIT_WD-1:0]       cxl_rx_cache_rsp_crdret,   // Status Register - CXL.cache Response Accumulated Credit Return
    output logic [FLIT_CRD_WD-1:0]        cxl_ll_cache_data_crdret,  // Credit Arbiter - 68B Flit RX Credit Return for CXL.cache Data
    output logic [FLIT_CRD_WD-1:0]        cxl_ll_cache_req_crdret,   // Credit Arbiter - 68B Flit RX Credit Return for CXL.cache Request
    output logic [FLIT_CRD_WD-1:0]        cxl_ll_cache_rsp_crdret,   // Credit Arbiter - 68B Flit RX Credit Return for CXL.cache Response
    output CRD_256B_t                     cxl_ll_cache_256B_crdret,  // Credit Arbiter - 256B Flit RX Credit Return for CXL.cache
    output logic                          cxl_ll_cache_crdret_done   // Link Credit FSM - CXL.cache Credit Initialization Done signal
    ,
    output logic [RX_CREDIT_WD-1:0]       cxl_rx_mem_data_crdret,    // Status Register - CXL.mem Data Accumulated Credit Return
    output logic [RX_CREDIT_WD-1:0]       cxl_rx_mem_ndr_crdret,     // Status Register - CXL.mem Request/Response Accumulated Credit Return
    output logic [RX_CREDIT_WD-1:0]       cxl_rx_mem_bi_crdret, 
    output logic [FLIT_CRD_WD-1:0]        cxl_ll_mem_data_crdret,    // Credit Arbiter - 68B Flit RX Credit Return for CXL.mem Data
    output logic [FLIT_CRD_WD-1:0]        cxl_ll_mem_req_crdret,     // Credit Arbiter - 68B Flit RX Credit Return for CXL.mem Request
    output logic [FLIT_CRD_WD-1:0]        cxl_ll_mem_rsp_crdret,     // Credit Arbiter - 68B Flit RX Credit Return for CXL.mem Response
    output CRD_256B_t                     cxl_ll_mem_256B_crdret,    // Credit Arbiter - 256B Flit RX Credit Return for CXL.mem
    output logic                          cxl_ll_mem_crdret_done     // Link Credit FSM - CXL.mem Credit Initialization Done signal
);

// Local Parameters
localparam CACHE = 1'b0;
localparam MEM   = 1'b1;
localparam LOC_CACHE_DATA_CRD_WD   = (CACHE_DATA_CRD_WD < RX_CREDIT_WD) ? (CACHE_DATA_CRD_WD+1) : RX_CREDIT_WD;
localparam LOC_CACHE_REQ_CRD_WD    = (CACHE_REQ_CRD_WD  < RX_CREDIT_WD) ? (CACHE_REQ_CRD_WD+1)  : RX_CREDIT_WD;
localparam LOC_CACHE_RSP_CRD_WD    = (CACHE_RSP_CRD_WD  < RX_CREDIT_WD) ? (CACHE_RSP_CRD_WD+1)  : RX_CREDIT_WD;
localparam LOC_CACHE_DATA_VALID_WD = 2; 
localparam LOC_MEM_DATA_CRD_WD     = (MEM_DATA_CRD_WD < RX_CREDIT_WD) ? (MEM_DATA_CRD_WD+1) : RX_CREDIT_WD;
localparam LOC_MEM_NDR_CRD_WD      = (MEM_NDR_CRD_WD  < RX_CREDIT_WD) ? (MEM_NDR_CRD_WD+1)  : RX_CREDIT_WD;
localparam LOC_MEM_DATA_VALID_WD   = 2 ;
localparam LOC_MEM_BI_CRD_WD       = (MEM_BI_CRD_WD  < RX_CREDIT_WD) ? (MEM_BI_CRD_WD+1)  : RX_CREDIT_WD;
localparam VALID_MAX_WD = (CXL_256B_FLIT_MODE_EN)? 6 : 4;
// Declarations
logic                        cxl_ll_init_done_r;
logic                        cxl_ll_crdret_set_s;
// CXL.cache RX Credit Return Counter signals
logic [DEC_CRD_WD-1:0]       s_cache_data_crd_dec   ; // RX Credit Counter Decrement - Transmitted Credit Return for CXL.cache Data
logic [DEC_CRD_WD-1:0]       s_cache_rsp_crd_dec    ; // RX Credit Counter Decrement - Transmitted Credit Return for CXL.cache Response
logic [DEC_CRD_WD-1:0]       s_cache_req_crd_dec    ; // RX Credit Counter Decrement - Transmitted Credit Return for CXL.cache Request
logic [2:0]                  s_cache_req_incr       ; // RX Credit Counter Increment - Number of offloaded CXL.cache Request messages from RX Buffer
logic [2:0]                  s_cache_rsp_incr       ; // RX Credit Counter Increment - Number of offloaded CXL.cache Response messages from RX Buffer
logic [2:0]                  s_cache_data_incr      ; // RX Credit Counter Increment - Number of offloaded CXL.cache Data messages from RX Buffer
logic                        s_cache_data_overflow  ; // RX Credit Counter Overflow for CXL.cache Data
logic                        s_cache_req_overflow   ; // RX Credit Counter Overflow for CXL.cache Request
logic                        s_cache_rsp_overflow   ; // RX Credit Counter Overflow for CXL.cache Response
logic [CACHE_DATA_CRD_WD:0]  s_cache_data_crd_cnt   ; // RX Credit Counter Next State for CXL.cache Data
logic [CACHE_REQ_CRD_WD:0]   s_cache_req_crd_cnt    ; // RX Credit Counter Next State for CXL.cache Request
logic [CACHE_RSP_CRD_WD:0]   s_cache_rsp_crd_cnt    ; // RX Credit Counter Next State for CXL.cache Response
logic [CACHE_DATA_CRD_WD:0]  r_cache_data_crd_cnt   ; // RX Credit Counter Register for CXL.cache Data
logic [CACHE_REQ_CRD_WD:0]   r_cache_req_crd_cnt    ; // RX Credit Counter Register for CXL.cache Request
logic [CACHE_RSP_CRD_WD:0]   r_cache_rsp_crd_cnt    ; // RX Credit Counter Register for CXL.cache Response

// Interface to Flit Formation (LLCTRL Flit Generator and Flit Packer)
logic [FLIT_CRD_WD-1:0]      s_ll_cache_data_crdret ; // 68B Flit RX Credit Return for CXL.cache Data
logic [FLIT_CRD_WD-1:0]      s_ll_cache_req_crdret  ; // 68B Flit RX Credit Return for CXL.cache Request
logic [FLIT_CRD_WD-1:0]      s_ll_cache_rsp_crdret  ; // 68B Flit RX Credit Return for CXL.cache Response
CRD_256B_t                   s_ll_cache_256B_crdret ; // 256B Flit RX Credit Return for CXL.cache

// CXL.mem RX Credit Return Counter signals
logic [DEC_CRD_WD-1:0]       s_mem_data_crd_dec     ; // RX Credit Counter Decrement - Transmitted Credit Return for CXL.mem Data
logic [DEC_CRD_WD-1:0]       s_mem_req_crd_dec      ; // RX Credit Counter Decrement - Transmitted Credit Return for CXL.mem Request
logic [DEC_CRD_WD-1:0]       s_mem_rsp_crd_dec      ; // RX Credit Counter Decrement - Transmitted Credit Return for CXL.mem Response
logic [2:0]                  s_mem_ndr_incr         ; // RX Credit Counter Increment - Number of offloaded CXL.mem Request/Response messages from RX Buffer
logic [2:0]                  s_mem_data_incr        ; // RX Credit Counter Increment - Number of offloaded CXL.mem Data messages from RX Buffer
logic                        s_mem_data_overflow    ; // RX Credit Counter Overflow for CXL.mem Data
logic                        s_mem_ndr_overflow     ; // RX Credit Counter Overflow for CXL.mem Request/Response
logic [MEM_DATA_CRD_WD:0]    s_mem_data_crd_cnt     ; // RX Credit Counter Next State for CXL.mem Data
logic [MEM_NDR_CRD_WD:0]     s_mem_ndr_crd_cnt      ; // RX Credit Counter Next State for CXL.mem Request/Response
logic [MEM_DATA_CRD_WD:0]    r_mem_data_crd_cnt     ; // RX Credit Counter Register for CXL.mem Data
logic [MEM_NDR_CRD_WD:0]     r_mem_ndr_crd_cnt      ; // RX Credit Counter Register for CXL.mem Request/Response

// Interface to Flit Formation (LLCTRL Flit Generator and Flit Packer)
logic [FLIT_CRD_WD-1:0]      s_ll_mem_data_crdret   ; // 68B Flit RX Credit Return for CXL.mem Data
logic [FLIT_CRD_WD-1:0]      s_ll_mem_req_crdret    ; // 68B Flit RX Credit Return for CXL.mem Request
logic [FLIT_CRD_WD-1:0]      s_ll_mem_rsp_crdret    ; // 68B Flit RX Credit Return for CXL.mem Response
CRD_256B_t                   s_ll_mem_256B_crdret   ; // 256B Flit RX Credit Return for CXL.mem

// CXL.mem Back-Invalidate RX Credit Return Counter signals
logic [DEC_CRD_WD-1:0]       s_mem_bi_crd_dec       ; // RX Credit Counter Decrement - Transmitted Credit Return for CXL.mem BI-Snoop/Response
logic [2:0]                  s_mem_bi_incr          ; // RX Credit Counter Increment - Number of offloaded CXL.mem BI-Snoop/Response messages from RX Buffer
logic                        s_mem_bi_overflow      ; // RX Credit Counter Overflow for CXL.mem BI-Snoop/Response
logic [MEM_BI_CRD_WD:0]      s_mem_bi_crd_cnt       ; // RX Credit Counter Next State for CXL.mem BI-Snoop/Response
logic [MEM_BI_CRD_WD:0]      r_mem_bi_crd_cnt       ; // RX Credit Counter Register for CXL.mem BI-Snoop/Response


// Indicate CXL Receiver Credit Return Error on credit counter overflow
assign cxl_ll_crdret_error[5] = 1'b0 || s_mem_bi_overflow ;
assign cxl_ll_crdret_error[4] = 1'b0     || s_mem_data_overflow ;
assign cxl_ll_crdret_error[3] = 1'b0     || s_mem_ndr_overflow ;
assign cxl_ll_crdret_error[2] = 1'b0   || s_cache_data_overflow ;
assign cxl_ll_crdret_error[1] = 1'b0   || s_cache_rsp_overflow ;
assign cxl_ll_crdret_error[0] = 1'b0   || s_cache_req_overflow ;

// -------------------------------------------------------------------------------------
// Detect Link Initialization done rising edge to preset Credit Return counters
// -------------------------------------------------------------------------------------
assign cxl_ll_crdret_set_s = cxl_ll_init_done & ~cxl_ll_init_done_r;

delay_n
 #(
    .N     (1),
    .WD    (1)
) u_init_done_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (cxl_ll_init_done),
    .dout  (cxl_ll_init_done_r)
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// CXL.cache Credit Return Counters
// -------------------------------------------------------------------------------------
// Credit Initialization Done to Link Initialization FSM
assign cxl_ll_cache_crdret_done = cxl_ll_init_done_r & (cfg_cache_enable ? ((r_cache_data_crd_cnt == 0) && (r_cache_req_crd_cnt == 0) && (r_cache_rsp_crd_cnt == 0)) : 1'b1);

// Credit Return Fields Encoding for 68B Flit Mode
assign s_ll_cache_data_crdret   = {CACHE, encode_credit({{(10-CACHE_DATA_CRD_WD){1'b0}}, s_cache_data_crd_cnt})};
assign s_ll_cache_req_crdret    = {CACHE, encode_credit({{(10-CACHE_REQ_CRD_WD ){1'b0}}, s_cache_req_crd_cnt })};
assign s_ll_cache_rsp_crdret    = {CACHE, encode_credit({{(10-CACHE_RSP_CRD_WD ){1'b0}}, s_cache_rsp_crd_cnt })};

// Credit Return Fields Encoding for 256B Flit Mode
assign s_ll_cache_256B_crdret   = CRD_256B_t'{RSVD: 1'b0, CRD_C: enc_tx_crd_256byte(cxl_device_mode, CACHE, {{(10-CACHE_RSP_CRD_WD ){1'b0}}, s_cache_rsp_crd_cnt }),
                                                          CRD_B: enc_tx_crd_256byte(cxl_device_mode, CACHE, {{(10-CACHE_DATA_CRD_WD){1'b0}}, s_cache_data_crd_cnt}),
                                                          CRD_A: enc_tx_crd_256byte(cxl_device_mode, CACHE, {{(10-CACHE_REQ_CRD_WD ){1'b0}}, s_cache_req_crd_cnt })};

// Accumulated Credit Return Information for CXL Link RX Credit Return Status Register
assign cxl_rx_cache_data_crdret = {{(RX_CREDIT_WD-LOC_CACHE_DATA_CRD_WD){1'b0}}, r_cache_data_crd_cnt[LOC_CACHE_DATA_CRD_WD-1:0]};
assign cxl_rx_cache_req_crdret  = {{(RX_CREDIT_WD-LOC_CACHE_REQ_CRD_WD ){1'b0}}, r_cache_req_crd_cnt[LOC_CACHE_REQ_CRD_WD-1:0]};
assign cxl_rx_cache_rsp_crdret  = {{(RX_CREDIT_WD-LOC_CACHE_RSP_CRD_WD ){1'b0}}, r_cache_rsp_crd_cnt[LOC_CACHE_RSP_CRD_WD-1:0]};

// Extract Credit Return Fields from LLCRD flits or protocol flits
assign s_cache_req_crd_dec  = cxl_pcie_flit_mode ? dec_tx_crd_256byte(cxl_256B_tx_crdret[ 4: 0], CACHE, cxl_device_mode) : dec_credit(cxl_cache_req_crd );
assign s_cache_data_crd_dec = cxl_pcie_flit_mode ? dec_tx_crd_256byte(cxl_256B_tx_crdret[ 9: 5], CACHE, cxl_device_mode) : dec_credit(cxl_cache_data_crd);
assign s_cache_rsp_crd_dec  = cxl_pcie_flit_mode ? dec_tx_crd_256byte(cxl_256B_tx_crdret[14:10], CACHE, cxl_device_mode) : dec_credit(cxl_cache_rsp_crd );

// Count the number of valid inputs for request and response offloaded from the Receive Buffer
assign s_cache_req_incr  = count_valid({{(VALID_MAX_WD-CACHE_REQ_VALID_WD     ){1'b0}}, cxl_rx_cache_req_valid});
assign s_cache_rsp_incr  = count_valid({{(VALID_MAX_WD-CACHE_RSP_VALID_WD     ){1'b0}}, cxl_rx_cache_rsp_valid});
assign s_cache_data_incr = count_valid({{(VALID_MAX_WD-LOC_CACHE_DATA_VALID_WD){1'b0}}, cxl_rx_cache_data_valid});

// Credit Return Counters
always_comb begin
    s_cache_data_overflow = 1'b0;
    s_cache_req_overflow  = 1'b0;
    s_cache_rsp_overflow  = 1'b0;
    // Initalize RX Credit Returns from CXL Link Rx Credit Control Register
    if (cxl_ll_crdret_set_s) begin
        s_cache_data_crd_cnt  = {{((CACHE_DATA_CRD_WD + 1) - LOC_CACHE_DATA_CRD_WD){1'b0}}, cfg_rx_cache_data_credits[LOC_CACHE_DATA_CRD_WD-1:0]};
        s_cache_req_crd_cnt   = {{((CACHE_REQ_CRD_WD  + 1) - LOC_CACHE_REQ_CRD_WD ){1'b0}}, cfg_rx_cache_req_credits[LOC_CACHE_REQ_CRD_WD-1:0]};
        s_cache_rsp_crd_cnt   = {{((CACHE_RSP_CRD_WD  + 1) - LOC_CACHE_RSP_CRD_WD ){1'b0}}, cfg_rx_cache_rsp_credits[LOC_CACHE_RSP_CRD_WD-1:0]};
    end
    else if (cfg_cache_enable && cxl_ll_init_done_r) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The desing should never overflow the counter, if it happens it raises assertion error.
        s_cache_data_crd_cnt  = r_cache_data_crd_cnt + s_cache_data_incr - s_cache_data_crd_dec;
        s_cache_data_overflow = s_cache_data_crd_cnt[CACHE_DATA_CRD_WD] & ((CACHE_DATA_CRD_WD < RX_CREDIT_WD) ? (|s_cache_data_crd_cnt[CACHE_DATA_CRD_WD-1:0]) : 1'b1);
        
        s_cache_req_crd_cnt   = r_cache_req_crd_cnt + s_cache_req_incr - s_cache_req_crd_dec;
        s_cache_req_overflow  = s_cache_req_crd_cnt[CACHE_REQ_CRD_WD] & ((CACHE_REQ_CRD_WD < RX_CREDIT_WD) ? (|s_cache_req_crd_cnt[CACHE_REQ_CRD_WD-1:0]) : 1'b1);
        
        s_cache_rsp_crd_cnt   = r_cache_rsp_crd_cnt + s_cache_rsp_incr - s_cache_rsp_crd_dec;
        s_cache_rsp_overflow  = s_cache_rsp_crd_cnt[CACHE_RSP_CRD_WD] & ((CACHE_RSP_CRD_WD < RX_CREDIT_WD) ? (|s_cache_rsp_crd_cnt[CACHE_RSP_CRD_WD-1:0]) : 1'b1);
// spyglass enable_block W164a
    end
    else begin
        s_cache_data_crd_cnt  = r_cache_data_crd_cnt;
        s_cache_req_crd_cnt   = r_cache_req_crd_cnt;
        s_cache_rsp_crd_cnt   = r_cache_rsp_crd_cnt;
    end
end

// Register creation
always_ff @(posedge core_clk or negedge core_rst_n) begin : cache_credit_proc
    if (!core_rst_n) begin
        r_cache_data_crd_cnt      <= # TP '0;
        r_cache_req_crd_cnt       <= # TP '0;
        r_cache_rsp_crd_cnt       <= # TP '0;
        cxl_ll_cache_data_crdret  <= # TP {FLIT_CRD_WD{1'b0}};
        cxl_ll_cache_req_crdret   <= # TP {FLIT_CRD_WD{1'b0}};
        cxl_ll_cache_rsp_crdret   <= # TP {FLIT_CRD_WD{1'b0}};
        cxl_ll_cache_256B_crdret  <= # TP 16'd0;
    end else begin
        r_cache_data_crd_cnt      <= # TP s_cache_data_crd_cnt;
        r_cache_req_crd_cnt       <= # TP s_cache_req_crd_cnt;
        r_cache_rsp_crd_cnt       <= # TP s_cache_rsp_crd_cnt;
        cxl_ll_cache_data_crdret  <= # TP s_ll_cache_data_crdret;
        cxl_ll_cache_req_crdret   <= # TP s_ll_cache_req_crdret;
        cxl_ll_cache_rsp_crdret   <= # TP s_ll_cache_rsp_crdret;
        cxl_ll_cache_256B_crdret  <= # TP s_ll_cache_256B_crdret;
    end
end : cache_credit_proc
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// CXL.cache Credit Return Counters
// -------------------------------------------------------------------------------------
// Credit Initialization Done to Link Initialization FSM
assign cxl_ll_mem_crdret_done = cxl_ll_init_done_r & (cfg_mem_enable ? ((r_mem_data_crd_cnt == 0) && (r_mem_ndr_crd_cnt == 0) && ((r_mem_bi_crd_cnt == 0) || ~cxl_pcie_flit_mode)) : 1'b1);

// Credit Return Fields Encoding for 68B Flit Mode
assign s_ll_mem_data_crdret = {MEM, encode_credit({{(10-MEM_DATA_CRD_WD){1'b0}}, s_mem_data_crd_cnt})};

assign s_ll_mem_req_crdret  = cxl_device_mode ? {FLIT_CRD_WD{1'b0}} : {MEM, encode_credit({{(10-MEM_NDR_CRD_WD){1'b0}}, s_mem_ndr_crd_cnt})};
assign s_ll_mem_rsp_crdret  = cxl_device_mode ? {MEM, encode_credit({{(10-MEM_NDR_CRD_WD){1'b0}}, s_mem_ndr_crd_cnt})} : {FLIT_CRD_WD{1'b0}};

// Credit Return Fields Encoding for 256B Flit Mode
assign s_ll_mem_256B_crdret = CRD_256B_t'{RSVD: 1'b0, CRD_C: enc_tx_crd_256byte(cxl_device_mode, MEM, cxl_device_mode ? {{(10-MEM_NDR_CRD_WD){1'b0}}, s_mem_ndr_crd_cnt} : {{(10-MEM_BI_CRD_WD){1'b0}}, s_mem_bi_crd_cnt }),
                                                      CRD_B: enc_tx_crd_256byte(cxl_device_mode, MEM, {{(10-MEM_DATA_CRD_WD){1'b0}}, s_mem_data_crd_cnt}  ),
                                                      CRD_A: enc_tx_crd_256byte(cxl_device_mode, MEM, cxl_device_mode ? {{(10-MEM_BI_CRD_WD){1'b0}}, s_mem_bi_crd_cnt } : {{(10-MEM_NDR_CRD_WD){1'b0}}, s_mem_ndr_crd_cnt})};

// Accumulated Credit Return Information for RX Link Layer Credit Return Status Register
assign cxl_rx_mem_data_crdret = {{(RX_CREDIT_WD-LOC_MEM_DATA_CRD_WD){1'b0}}, r_mem_data_crd_cnt[LOC_MEM_DATA_CRD_WD-1:0]};
assign cxl_rx_mem_ndr_crdret  = {{(RX_CREDIT_WD-LOC_MEM_NDR_CRD_WD ){1'b0}}, r_mem_ndr_crd_cnt[LOC_MEM_NDR_CRD_WD-1:0]};

assign cxl_rx_mem_bi_crdret = {{(RX_CREDIT_WD-LOC_MEM_BI_CRD_WD ){1'b0}}, r_mem_bi_crd_cnt[LOC_MEM_BI_CRD_WD -1:0]};

// Extract Credit Return Fields from LLCRD flits or protocol flits
assign s_mem_data_crd_dec = cxl_pcie_flit_mode ? dec_tx_crd_256byte(cxl_256B_tx_crdret[ 9: 5], MEM, cxl_device_mode) : dec_credit(cxl_mem_data_crd);
assign s_mem_req_crd_dec  = cxl_pcie_flit_mode ? dec_tx_crd_256byte(cxl_256B_tx_crdret[ 4: 0], MEM, cxl_device_mode) : dec_credit(cxl_mem_req_crd);
assign s_mem_rsp_crd_dec  = cxl_pcie_flit_mode ? dec_tx_crd_256byte(cxl_256B_tx_crdret[14:10], MEM, cxl_device_mode) : dec_credit(cxl_mem_rsp_crd);
// In 256B Flit Mode, for Root-Complex extract S2M BI-Snoop from CRD_A and for Endpoint extract M2S BI-Response from CRD_C
assign s_mem_bi_crd_dec   = cxl_pcie_flit_mode ? dec_tx_crd_256byte(cxl_device_mode ? cxl_256B_tx_crdret[4:0] : cxl_256B_tx_crdret[14:10], MEM, cxl_device_mode) : '0;

// Count the number of valid inputs for request and response offloaded from the Receive Buffer
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: count_valid value is limited by the maximum number of messages, hence LHS is less that RHS width.
assign s_mem_ndr_incr  = count_valid({{(VALID_MAX_WD-MEM_NDR_VALID_WD){1'b0}}, cxl_rx_mem_ndr_valid}) ;
// spyglass enable_block W164a
assign s_mem_bi_incr   = count_valid({{(VALID_MAX_WD-MEM_BI_VALID_WD){1'b0}}, cxl_rx_mem_bi_valid});
assign s_mem_data_incr = count_valid({{(VALID_MAX_WD-LOC_MEM_DATA_VALID_WD){1'b0}}, cxl_rx_mem_data_valid });

// Credit return counters for CXL.mem Data and Request/Response message
always_comb begin
    s_mem_data_overflow = 1'b0;
    s_mem_ndr_overflow  = 1'b0;
    if (cxl_ll_crdret_set_s) begin
        s_mem_data_crd_cnt  = {{((MEM_DATA_CRD_WD + 1) - LOC_MEM_DATA_CRD_WD){1'b0}}, cfg_rx_mem_data_credits[LOC_MEM_DATA_CRD_WD-1:0]};
        s_mem_ndr_crd_cnt   = {{((MEM_NDR_CRD_WD + 1) - LOC_MEM_NDR_CRD_WD){1'b0}}, cfg_rx_mem_ndr_credits[LOC_MEM_NDR_CRD_WD-1:0]};
    end
    else if (cfg_mem_enable && cxl_ll_init_done_r) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The desing should never overflow the counter, if it happens it raises assertion error.
        s_mem_data_crd_cnt  = r_mem_data_crd_cnt + s_mem_data_incr - s_mem_data_crd_dec;
        s_mem_data_overflow = s_mem_data_crd_cnt[MEM_DATA_CRD_WD] & ((MEM_DATA_CRD_WD < RX_CREDIT_WD) ? (|s_mem_data_crd_cnt[MEM_DATA_CRD_WD-1:0]) : 1'b1);
        
        s_mem_ndr_crd_cnt   = r_mem_ndr_crd_cnt + s_mem_ndr_incr - (s_mem_req_crd_dec & {DEC_CRD_WD{!cxl_device_mode}})
 - (s_mem_rsp_crd_dec & {DEC_CRD_WD{cxl_device_mode}}) ;
        s_mem_ndr_overflow  = s_mem_ndr_crd_cnt[MEM_NDR_CRD_WD] & ((MEM_NDR_CRD_WD < RX_CREDIT_WD) ? (|s_mem_ndr_crd_cnt[MEM_NDR_CRD_WD-1:0]) : 1'b1);
// spyglass enable_block W164a
    end
    else begin
        s_mem_data_crd_cnt  = r_mem_data_crd_cnt;
        s_mem_ndr_crd_cnt   = r_mem_ndr_crd_cnt;
    end
end

// Credit return counters for CXL.mem BI-Snoop/Response message
always_comb begin
    s_mem_bi_overflow  = 1'b0;
    if (cxl_ll_crdret_set_s) begin
        s_mem_bi_crd_cnt   = {{((MEM_BI_CRD_WD + 1) - LOC_MEM_BI_CRD_WD){1'b0}}, cfg_rx_mem_bi_credits[LOC_MEM_BI_CRD_WD-1:0]};
    end
    else if (cfg_mem_enable && cxl_ll_init_done_r) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The desing should never overflow the counter, if it happens it raises assertion error.
        s_mem_bi_crd_cnt   = r_mem_bi_crd_cnt + s_mem_bi_incr - s_mem_bi_crd_dec;
        s_mem_bi_overflow  = s_mem_bi_crd_cnt[MEM_BI_CRD_WD] & ((MEM_BI_CRD_WD < RX_CREDIT_WD) ? (|s_mem_bi_crd_cnt[MEM_BI_CRD_WD-1:0]) : 1'b1);
// spyglass enable_block W164a
    end
    else begin
        s_mem_bi_crd_cnt   = r_mem_bi_crd_cnt;
    end
end

// Register creation
always_ff @(posedge core_clk or negedge core_rst_n) begin : mem_credit_proc
    if (!core_rst_n) begin
        r_mem_data_crd_cnt        <= # TP '0;
        r_mem_ndr_crd_cnt         <= # TP '0;
        r_mem_bi_crd_cnt          <= # TP '0;
        cxl_ll_mem_data_crdret    <= # TP {FLIT_CRD_WD{1'b0}};
        cxl_ll_mem_req_crdret     <= # TP {FLIT_CRD_WD{1'b0}};
        cxl_ll_mem_rsp_crdret     <= # TP {FLIT_CRD_WD{1'b0}};
        cxl_ll_mem_256B_crdret    <= # TP 16'd0;
    end else begin
        r_mem_data_crd_cnt        <= # TP s_mem_data_crd_cnt;
        r_mem_ndr_crd_cnt         <= # TP s_mem_ndr_crd_cnt;
        r_mem_bi_crd_cnt          <= # TP s_mem_bi_crd_cnt;
        cxl_ll_mem_data_crdret    <= # TP s_ll_mem_data_crdret;
        cxl_ll_mem_req_crdret     <= # TP s_ll_mem_req_crdret;
        cxl_ll_mem_rsp_crdret     <= # TP s_ll_mem_rsp_crdret;
        cxl_ll_mem_256B_crdret    <= # TP s_ll_mem_256B_crdret;
    end
end : mem_credit_proc

// -------------------------------------------------------------------------------------
// Decode Credit Return for 68B Flit Format
// -------------------------------------------------------------------------------------
function automatic [DEC_CRD_WD-1:0] dec_credit (
  input [CRD_RET_WD-1:0] credit_return
);
  begin
    case (credit_return)
      3'b000 : dec_credit = 'd0;
      3'b001 : dec_credit = 'd1;
      3'b010 : dec_credit = 'd2;
      3'b011 : dec_credit = 'd4;
      3'b100 : dec_credit = 'd8;
      3'b101 : dec_credit = 'd16;
      3'b110 : dec_credit = 'd32;
      3'b111 : dec_credit = 'd64;
    endcase
  end
  return dec_credit;
endfunction
// -------------------------------------------------------------------------------------
/*   
         //device_type = 1                            //device_type = 0
 ////////////////////////////////////      //////////////////////////////////// 
 //             Host               //      //             Device             // 
 //          Root-Complex          //      //            Endpoint            // 
 ////////////////////////////////////      ////////////////////////////////////
                                      
 ////////////////////////////////////      //////////////////////////////////// 
 //    TX : Host (Root-Complex)    //      //   RX : Device (Endpoint)       //
 //                                //      ////////////////////////////////////
 ////////////////////////////////////      //                                //
 //                                //      //////////////// //////////////// // 
 // ////////////////////////////// //      //// RX Queue // //  CDR RX    // // 
 // //   CDR TX   //   CDR TX   // //      //////////////// //  decoder   // // 
 // //   encoder  //   decoder  // //      //// receive  // //(D2H & S2M) // // 
 // // (D2H & S2M)// (D2H & S2M)// // >>>> ////H2D + M2S // //  of the    // // 
 // //   of the   // overflow of// //      //// messages // // Host queue // // 
 // // Host queue // Host queue // //      //////////////// //////////////// // 
 // /////////////////////////////////      //                                // 
 ////////////////////////////////////      ////////////////////////////////////
                                      
 ////////////////////////////////////      ////////////////////////////////////
 //    RX : Host (Root-Complex)    //      //     TX : Device (Endpoint)     //
 ////////////////////////////////////      //                                //
 //                                //      //////////////////////////////////// 
 //////////////// //////////////// //      //                                // 
 //// RX Queue // //  CDR RX    // //      // ////////////////////////////// // 
 //////////////// //  decoder   // //      // //   CDR TX   //   CDR TX   // // 
 //// receive  // //(H2D & M2S) // // <<<< // //   encoder  //   decoder  // // 
 ////D2H + S2M // //  of the    // //      // // (H2D & M2S)// (H2D & M2S)// // 
 //// messages // //Device queue// //      // //   of the   //overflow of // // 
 //////////////// //////////////// //      // //Device queue//Device queue// // 
 //                                //      // /////////////////////////////////
 ////////////////////////////////////      //////////////////////////////////// 
 */
// -------------------------------------------------------------------------------------
// Decode Credit Return for 256B Flit Format                                            
// -------------------------------------------------------------------------------------
function automatic [DEC_CRD_WD-1:0] dec_tx_crd_256byte (                                
    input [4:0] credit_return, // Credit Return field from 2B CRD field                 
    input       protocol_type, // 0 - CXL.cache, 1 - CXL.mem                            
    input       device_type    // 0 - Endpoint, 1 - Root-Complex                        
);                                                                                      
  begin                                                                                                          
    if (credit_return == 5'd0) begin                                                                             
        dec_tx_crd_256byte = 'd0;                                                                                
    end                                                                                                          
    else begin                                                                                                   
        // CXL.cache decode                                                                                      
        if (!protocol_type) begin                                                                                
            // Endpoint                                                                                          
            if (!device_type) begin                                                                              
                case (credit_return) // H2D Request/H2D Data/H2D Response                                        
                    5'h04  : dec_tx_crd_256byte = 'd1  ;                                                         
                    5'h05  : dec_tx_crd_256byte = 'd4  ;                                                         
                    5'h06  : dec_tx_crd_256byte = 'd8  ;                                                         
                    5'h07  : dec_tx_crd_256byte = 'd12 ;                                                         
                    5'h08  : dec_tx_crd_256byte = 'd16 ;                                                         
                    default: dec_tx_crd_256byte = 'd0  ; // Do we need to raise an error                         
                endcase                                                                                          
            end                                                                                                  
            // Root-Complex                                                                                              
            else begin                                                                                                   
                case (credit_return) // D2H Request/D2H Data/D2H Response                                                
                    // Upstream Decode                                                                                   
                    5'h09  : dec_tx_crd_256byte = 'd1  ;                                                                 
                    5'h0A  : dec_tx_crd_256byte = 'd4  ;                                                                 
                    5'h0B  : dec_tx_crd_256byte = 'd8  ;                                                                 
                    5'h0C  : dec_tx_crd_256byte = 'd12 ;                                                                     
                    5'h0D  : dec_tx_crd_256byte = 'd16 ;                                                                     
                    default: dec_tx_crd_256byte = 'd0  ; // Do we need to raise an error                                     
                endcase                                                                                                      
            end                                                                                                              
        end                                                                                                                  
        // CXL.mem decode                                                                                                    
        else begin                                                                                                           
            // Endpoint                                                                                                      
            if (!device_type) begin                                                                                          
                case (credit_return) // M2S Request/M2S Data/M2S BI-Response            
                    5'h14  : dec_tx_crd_256byte = 'd1  ;                                   
                    5'h15  : dec_tx_crd_256byte = 'd4  ;                                          
                    5'h16  : dec_tx_crd_256byte = 'd8  ;                                          
                    5'h17  : dec_tx_crd_256byte = 'd12 ;                                          
                    5'h18  : dec_tx_crd_256byte = 'd16 ;                                          
                    default: dec_tx_crd_256byte = 'd0  ; // Do we need to raise an error          
                endcase                                                                           
            end                                                                                   
            // Root-Complex                                                                       
            else begin                                                                            
                case (credit_return) // S2M BI-Snoop/S2M Data/S2M Response                        
                    5'h19  : dec_tx_crd_256byte = 'd1  ;                                
                    5'h1A  : dec_tx_crd_256byte = 'd4  ;                                
                    5'h1B  : dec_tx_crd_256byte = 'd8  ;                                
                    5'h1C  : dec_tx_crd_256byte = 'd12 ;                                
                    5'h1D  : dec_tx_crd_256byte = 'd16 ;                                
                    default: dec_tx_crd_256byte = 'd0  ; // Do we need to raise an error
                endcase                                                                 
            end                                                                         
        end // protocol_type                                                            
    end // no credit                                                                    
  end                                                                                   
  return dec_tx_crd_256byte;                                                            
endfunction                                                                             
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// Encode Credit Return for 68B Flit Format                                             
// -------------------------------------------------------------------------------------
function automatic [CRD_RET_WD-1:0] encode_credit (
  input [10:0] credit_cnt
);
  begin
    unique casez ({(|credit_cnt[10:6]), credit_cnt[5:0]})
      7'b1??????: encode_credit = 3'b111; // (credit_cnt >= 64)
      7'b01?????: encode_credit = 3'b110; // (credit_cnt >= 32)
      7'b001????: encode_credit = 3'b101; // (credit_cnt >= 16)
      7'b0001???: encode_credit = 3'b100; // (credit_cnt >= 8)
      7'b00001??: encode_credit = 3'b011; // (credit_cnt >= 4)
      7'b000001?: encode_credit = 3'b010; // (credit_cnt >= 2)
      7'b0000001: encode_credit = 3'b001; // (credit_cnt >= 1)
      default   : encode_credit = '0;
    endcase
  end
  return encode_credit;
endfunction
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Encode Credit Return for 256B Flit Format
// -------------------------------------------------------------------------------------
function automatic [4:0] enc_tx_crd_256byte (
    input        device_type,    // 0 - Endpoint, 1 - Root-Complex
    input        protocol_type,  // 0 - CXL.cache, 1 - CXL.mem
    input [10:0] credit_cnt      // Request Credit Return Counter
);
  begin
    unique casez ({(|credit_cnt[10:4]), credit_cnt[3:0]})
      5'b1????: enc_tx_crd_256byte = protocol_type ? (device_type ? 5'h1D : 5'h18) : (device_type ? 5'h0D : 5'h08); // (credit_cnt >= 16)
      5'b011??: enc_tx_crd_256byte = protocol_type ? (device_type ? 5'h1C : 5'h17) : (device_type ? 5'h0C : 5'h07); // (credit_cnt >= 12)
      5'b010??: enc_tx_crd_256byte = protocol_type ? (device_type ? 5'h1B : 5'h16) : (device_type ? 5'h0B : 5'h06); // (credit_cnt >= 8)
      5'b001??: enc_tx_crd_256byte = protocol_type ? (device_type ? 5'h1A : 5'h15) : (device_type ? 5'h0A : 5'h05); // (credit_cnt >= 4)
      5'b0001?,  
      5'b00001: enc_tx_crd_256byte = protocol_type ? (device_type ? 5'h19 : 5'h14) : (device_type ? 5'h09 : 5'h04); // (credit_cnt >= 3)
      default : enc_tx_crd_256byte = '0;
    endcase
  end
  return enc_tx_crd_256byte;
endfunction
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Count valid inputs
// -------------------------------------------------------------------------------------
function automatic [2:0] count_valid (
    input [VALID_MAX_WD -1:0] valid
);
  begin
    integer a;
    count_valid = 'd0;
    for (a = 0; a < VALID_MAX_WD; a = a + 1) begin
      if (valid[a])
        count_valid = count_valid + 'd1;
    end
  end
  return count_valid;
endfunction
// -------------------------------------------------------------------------------------

endmodule
