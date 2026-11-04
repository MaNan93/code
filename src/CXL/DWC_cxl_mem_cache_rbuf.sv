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
// ---   $Revision: #10 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rbuf.sv#10 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Retry Buffer
// Retry Buffer Read and Write Control
// ESEQ Number
// Read/Write Pointers
// NumFreeBuff Tracking
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_mem_cache_rbuf
  import DWC_cxl_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;

#(
  parameter TP = `TP
)(
  // Inputs
  input                                 core_clk,
  input                                 core_rst_n,
  input [(CXL_DATA_WD - 1) : 0]         cxl_retryable_flit,         // Retryable flit to be stored in the retry buffer

  input                                 cxl_retryable_valid,        // When set to 1 the retryable flit is valid
  input                                 cxl_llctrl_rbuf_en,         // Enable Retry Buffer
  input                                 cxl_llctrl_rbuf_halt,       // Halt to the retry buffer
  input                                 cxl_rrsm_retry_normal,      // RRSM is in the normal state
  input                                 cxl_rx_retry_req,           // Received Retry Request
  input [(ESEQ_WD - 1) : 0]             cxl_rx_eseq,                // Received ESEQ number
  input [(ESEQ_WD - 1) : 0]             cxl_init_llr_wrap,          // ESEQ number wrap value
  input [(ACK_CNT_WD - 1) : 0]          cxl_rx_full_ack,            // Received Full Ack
  input                                 cxl_rrsm_retry_req,         // Retry request
  input                                 cxl_lrsm_inc_eseq,          // Increment expected sequence number - ESeq
  input [(RBUF_DATA_WD - 1) : 0]        rbuf_ram_rdata,             // Retry buffer read data
  output ras_dp_err_log_t               ras_dp_err_log            , // Error Logs from RASDP instances
  output                  [CXL_RBUF_RAS_UNCORR_NUM-1:0]         ras_dp_uncorr_err         , // RASDP Errors to trigger Viral
  input  ras_dp_err_inj_t               ras_dp_err_inj,
  // Outputs
  output logic                          cxl_rbuf_eseq_ovflw,        // Retry buffer ESEQ Overflow
  output logic [(RBUF_ADD_WD - 1) : 0]  cxl_rbuf_addr,              // Retry buffer address
  output logic                          cxl_rbuf_addr_par,          // Retry buffer address Parity
  output logic [(RBUF_ADD_WD - 1) : 0]  cxl_rbuf_wr_ptr,            // Retry buffer write pointer
  output logic                          cxl_rbuf_en,                // Retry buffer enable
  output logic                          cxl_rbuf_wen,               // Retry buffer write enable
  output logic [(RBUF_DATA_WD - 1) : 0] cxl_rbuf_wdata,             // Retry buffer write data
  output logic                          cxl_rbuf_flit_valid,        // Retry Buffer flit valid
  output logic [(CXL_DATA_WD - 1) : 0]  cxl_rbuf_flit,              // Retry Buffer flit

  output logic [(RBUF_ADD_WD - 1) : 0]  cxl_rbuf_numfree,           // Number of free spaces in the retry buffer
  output logic                          cxl_rbuf_retry_done,        // Retry done indication
  output logic [(RBUF_ADD_WD - 1) : 0]  cxl_rbuf_consumed,          // Consumed spaces in the retry buffer
  output logic [(ESEQ_WD - 1) : 0]      cxl_rbuf_eseq               // ESEQ number
);

// Parameter Declarations
localparam [(RBUF_ADD_WD - 1) : 0] INCR_BY_1 = {{(RBUF_ADD_WD - 1){1'b0}}, 1'b1};
localparam [(RBUF_ADD_WD - 1) : 0] RBUF_WRAP_ADD = {RBUF_ADD_WD{1'b1}};

// Logic Declarations
logic [(RBUF_ADD_WD - 1) : 0]  s_rbuf_numfree;       // RBUF Number of free elements
logic                          s_rbuf_numfree_ovflw; // RBUF Number of free elements overflow
logic [(RBUF_ADD_WD - 1) : 0]  s_rbuf_consumed;      // RBUF Number of consumed elements
logic                          s_incr_wr_ptr;        // RBUF Write Pointer Increment
logic [RBUF_ADD_WD-1:0]        s_rbuf_wr_ptr;        // RBUF Next Write Pointer
logic [RBUF_ADD_WD-1:0]        s_rbuf_rd_ptr;        // RBUF Next Read Pointer
logic [RBUF_ADD_WD-1:0]        cxl_rbuf_rd_ptr;      // RBUF Read Pointer Register

logic [(RBUF_ADD_WD - 1) : 0]  s_rbuf_rd_addr;       // RBUF FSM Read Address
logic                          s_rbuf_rd_en;         // RBUF FSM Read Enable
logic [(RBUF_ADD_WD - 1) : 0]  s_rbuf_addr;          // RBUF RAM Address
logic [(RBUF_ADD_WD - 1) : 0]  s_rbuf_addr_int;      // RBUF RAM Address
logic                          s_rbuf_addr_par;      // RBUF RAM Address Parity
logic                          s_rbuf_en;            // RBUF RAM Memory Enable
logic                          s_rbuf_wen;           // RBUF RAM Write Enable
logic [CX_CXL_20_DW - 1 : 0]   s_rbuf_wdata_int;     // RBUF RAM Write Data
logic [(RBUF_DATA_WD - 1) : 0] s_rbuf_wdata;         // RBUF RAM Write Data
logic [(RBUF_DATA_WD - 1) : 0] cxl_rbuf_rdata_out;
logic [(CX_CXL_20_DW - 1) : 0] cxl_rbuf_flit_s;      // Retry Buffer flit (after RAS checking)
logic [15:0]                   rbuf_flit_crc_s;      // RBUF Flit CRC
logic                          rbuf_flit_crc_err_s;  // RBUF Flit CRC Error

// ----------------------------------------------------------------------------
// Retry Buffer FSM Instantiation
// ----------------------------------------------------------------------------
DWC_cxl_mem_cache_rbuf_fsm
 u_rbuf_fsm (
    // Inputs
    .core_clk              (core_clk),
    .core_rst_n            (core_rst_n),
    .cxl_rx_retry_req      (cxl_rx_retry_req),
    .cxl_rx_eseq           (cxl_rx_eseq),
    .cxl_rrsm_retry_normal (cxl_rrsm_retry_normal),
    .cxl_rrsm_retry_req    (cxl_rrsm_retry_req),
    .cxl_rbuf_wr_ptr       (cxl_rbuf_wr_ptr),
    .cxl_rbuf_rd_ptr       (cxl_rbuf_rd_ptr),
    .cxl_retryable_valid   (cxl_retryable_valid),
    .cxl_llctrl_rbuf_en    (cxl_llctrl_rbuf_en),
    .cxl_llctrl_rbuf_halt  (cxl_llctrl_rbuf_halt),
    .rbuf_ram_rdata        (rbuf_ram_rdata),

    // Outputs
    .cxl_rbuf_rd_addr      (s_rbuf_rd_addr),
    .cxl_rbuf_rd_en        (s_rbuf_rd_en),
    .cxl_rbuf_retry_done   (cxl_rbuf_retry_done),
    .cxl_rbuf_flit_valid   (cxl_rbuf_flit_valid),
    .cxl_rbuf_flit         (cxl_rbuf_rdata_out)
);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Read pointer generation which is used to read the contents out of the LLRB during a retry scenario
// ----------------------------------------------------------------------------
always_comb begin : next_read_ptr
    // The value of this pointer is set by the sequence number sent with the retransmission request (RETRY.Req message).
    if (cxl_rx_retry_req) begin
        s_rbuf_rd_ptr = cxl_rx_eseq;
    end
    // The RdPtr is incremented by one whenever a flit is sent, either from the LLRB in response to a retry request or 
    // when a new flit arrives from the transaction layer and irrespective of the states of the local or remote retry state machines.
    // RdPtr must stop incrementing after Retry.Req flit is received allowing ADF flits to be flashed.
    else if (cxl_rrsm_retry_normal ? cxl_retryable_valid : (cxl_rbuf_flit_valid && !cxl_llctrl_rbuf_halt)) begin
        s_rbuf_rd_ptr = cxl_rbuf_rd_ptr + 1;
    end
    else begin
        s_rbuf_rd_ptr = cxl_rbuf_rd_ptr;
    end
end : next_read_ptr
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Write Pointer Generation
// ----------------------------------------------------------------------------
// WrPtr may continue to increment after receiving Retry.Req message if there are pre-scheduled All Data Flits that are not yet sent over the link. 
// This implementation willl ensure that All Data Flits not interleaved with other flits are correctly logged into the Link Layer Retry Buffer.
assign s_incr_wr_ptr = cxl_retryable_valid;// && cxl_rrsm_retry_normal;

always_comb begin
    if (s_incr_wr_ptr) begin
        s_rbuf_wr_ptr = cxl_rbuf_wr_ptr + RBUF_ADD_WD'(1);
    end
    else begin
        s_rbuf_wr_ptr = cxl_rbuf_wr_ptr;
    end
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Retry Buffer State - Number of Free/Consumed Entries
// ----------------------------------------------------------------------------
assign s_rbuf_consumed = CXL_RBUF_SIZE - s_rbuf_numfree;

always_comb begin : numfree_proc
    if(s_incr_wr_ptr) begin
        {s_rbuf_numfree_ovflw, s_rbuf_numfree} = {1'b0, cxl_rbuf_numfree} - 1'b1 + (cxl_lrsm_inc_eseq ? cxl_rx_full_ack : ACK_CNT_WD'(0));
    end
    else begin
        {s_rbuf_numfree_ovflw, s_rbuf_numfree} = {1'b0, cxl_rbuf_numfree} + (cxl_lrsm_inc_eseq ? cxl_rx_full_ack : ACK_CNT_WD'(0));
    end
end : numfree_proc
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// ESEQ Counter
// ----------------------------------------------------------------------------
DWC_cxl_base_timer

  // Parameters
  #(
  .TIMER_WIDTH  (RBUF_ADD_WD)
  ) u_eseq (
  // Inputs
  .clk          (core_clk),
  .rst_n        (core_rst_n),
  .clear_timer  (1'b0),
  .hold_timer   (1'b0),
  .enable       (cxl_lrsm_inc_eseq),
  .timer_target (cxl_init_llr_wrap),
  .incr         (INCR_BY_1),
  // Outputs
  .timeout_r    (),
  .timeout      (),
  .timer_r      (cxl_rbuf_eseq)
);
// ----------------------------------------------------------------------------

// Retry Buffer RAM Interface
assign s_rbuf_addr_int  = s_rbuf_rd_en ? s_rbuf_rd_addr : cxl_rbuf_wr_ptr;
assign s_rbuf_en        = s_rbuf_rd_en || s_incr_wr_ptr;
assign s_rbuf_wen       = s_incr_wr_ptr;
assign s_rbuf_wdata_int = s_incr_wr_ptr ? cxl_retryable_flit[CX_CXL_20_DW-1:0] : {(CX_CXL_20_DW){1'b0}};

always_ff @(posedge core_clk or negedge core_rst_n) begin : r_rbuf_proc
    if(!core_rst_n) begin
        cxl_rbuf_wr_ptr     <= # TP {RBUF_ADD_WD{1'b0}};
        cxl_rbuf_rd_ptr     <= # TP {RBUF_ADD_WD{1'b0}};
        cxl_rbuf_numfree    <= # TP CXL_RBUF_SIZE;
        cxl_rbuf_consumed   <= # TP {RBUF_ADD_WD{1'b0}};
        cxl_rbuf_addr       <= # TP {RBUF_ADD_WD{1'b0}};
        cxl_rbuf_addr_par   <= # TP 1'b0;
        cxl_rbuf_en         <= # TP 1'b0;
        cxl_rbuf_wen        <= # TP 1'b0;
        cxl_rbuf_wdata      <= # TP {RBUF_DATA_WD{1'b0}};
        cxl_rbuf_eseq_ovflw <= # TP 1'b0;
    end
    else begin
        cxl_rbuf_wr_ptr     <= # TP { {(8-CXL_RBUF_WD){1'b0}}, s_rbuf_wr_ptr[CXL_RBUF_WD-1:0] };
        cxl_rbuf_rd_ptr     <= # TP { {(8-CXL_RBUF_WD){1'b0}}, s_rbuf_rd_ptr[CXL_RBUF_WD-1:0] };
        cxl_rbuf_numfree    <= # TP s_rbuf_numfree;
        cxl_rbuf_consumed   <= # TP s_rbuf_consumed;
        cxl_rbuf_addr       <= # TP s_rbuf_addr;
        cxl_rbuf_addr_par   <= # TP s_rbuf_addr_par;
        cxl_rbuf_en         <= # TP s_rbuf_en;
        cxl_rbuf_wen        <= # TP s_rbuf_wen;
        cxl_rbuf_wdata      <= # TP s_rbuf_wdata;
        cxl_rbuf_eseq_ovflw <= # TP s_rbuf_numfree_ovflw;
    end
end : r_rbuf_proc

assign cxl_rbuf_flit       = {{(CXL_DATA_WD-CX_CXL_20_DW){1'b0}},cxl_rbuf_flit_s};

  DWC_cxl_mem_cache_rbuf_ras_ms
   rbuf_ras (
    .core_clk                  ( core_clk                         ),
    .core_rst_n                ( core_rst_n                       ),
    .ras_dp_err_log            ( ras_dp_err_log                   ),
    .ras_dp_uncorr_err         ( ras_dp_uncorr_err                ),
    .ras_dp_err_inj            ( ras_dp_err_inj                   ),
    .cxl_rbuf_flit_valid       ( cxl_rbuf_flit_valid              ),
    .cxl_llctrl_rbuf_halt      ( cxl_llctrl_rbuf_halt             ),
    .rbuf_addr                 ( s_rbuf_addr_int                  ),
    .rbuf_wdata                ( s_rbuf_wdata_int                 ),
                                                                  
    .rbuf_rdata                ( cxl_rbuf_rdata_out               ),
    // outputs                                                    
    .rbuf_addr_protgen         ( s_rbuf_addr                      ),
    .rbuf_addr_par             ( s_rbuf_addr_par                  ),
    .rbuf_wdata_protgen        ( s_rbuf_wdata                     ),
    .rbuf_rdata_protgen        ( cxl_rbuf_flit_s                  )
  );




endmodule
