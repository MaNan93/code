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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rbuf_fsm.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Retry Buffer Control FSM
// Responsible for retry buffer RAM interface 
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_rbuf_fsm
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) (
    // Inputs
    input                           core_clk,
    input                           core_rst_n,
    input                           cxl_rx_retry_req,      // Received Retry Request
    input  [ESEQ_WD-1:0]            cxl_rx_eseq,           // Sequence number received from Retry.Ack
    input                           cxl_rrsm_retry_normal, // RRSM is in the normal state
    input                           cxl_rrsm_retry_req,    // RRSM request retry
    input  [RBUF_ADD_WD-1:0]        cxl_rbuf_wr_ptr,       // Retry Buffer Write Pointer
    input  [RBUF_ADD_WD-1:0]        cxl_rbuf_rd_ptr,       // Retry Buffer Read Pointer
    input                           cxl_retryable_valid,   // When set to 1 the retryable flit is valid
    input                           cxl_llctrl_rbuf_en,    // Enable Retry Buffer
    input                           cxl_llctrl_rbuf_halt,  // Halt signal to the retry buffer
    input  [RBUF_DATA_WD-1:0]       rbuf_ram_rdata,        // Data read back from the retry buffer

    // Outputs
    output logic [RBUF_ADD_WD-1:0]  cxl_rbuf_rd_addr,      // Address to Retry buffer
    output logic                    cxl_rbuf_rd_en,        // Read Enable to Retry buffer
    output logic                    cxl_rbuf_retry_done,   // Retry Buffer retry complete
    output logic                    cxl_rbuf_flit_valid,   // Flit valid
    output logic [RBUF_DATA_WD-1:0] cxl_rbuf_flit          // RBUF Flit
);

localparam RBUF_READ_LATENCY = 2;

// Declarations
rbuf_state_e             r_state, s_next_state; // RBUF FSM State
logic                    cxl_rbuf_restart_s;    // RBUF FSM Restart
logic                    cxl_rbuf_rd_vld_s;     // RBUF RAM Read Valid
logic                    cxl_rbuf_rd_done_s;    // RBUF RAM Read Complete
logic [RBUF_ADD_WD-1:0]  cxl_rbuf_rd_addr_nxt;  // RBUF RAM Read Address

// RBUF FIFO controller Signals
logic                    rbuf_fifo_we_s;        // RBUF FIFO Write Enable
logic                    rbuf_fifo_re_s;        // RBUF FIFO Read Enable
logic                    rbuf_fifo_valid_s;     // RBUF FIFO Data Out Valid
logic                    rbuf_fifo_empty_s;     // RBUF FIFO Empty Flag
logic                    rbuf_fifo_af_s;        // RBUF FIFO Almost Full Flag
logic                    rbuf_fifo_full_s;      // RBUF FIFO Full Flag
logic [RBUF_DATA_WD-1:0] rbuf_fifo_din_s;       // RBUF FIFO Data Input
logic [RBUF_DATA_WD-1:0] rbuf_fifo_dout_s;      // RBUF FIFO Data Output


// Assignments
assign cxl_rbuf_flit_valid = rbuf_fifo_valid_s;
assign cxl_rbuf_flit       = rbuf_fifo_dout_s;
assign cxl_rbuf_retry_done = (cxl_rbuf_wr_ptr == cxl_rbuf_rd_ptr);
assign cxl_rbuf_rd_done_s  = (cxl_rbuf_wr_ptr == cxl_rbuf_rd_addr);
assign cxl_rbuf_rd_en      = (r_state == CXL_RBUF_READ) & ~cxl_rbuf_restart_s & ~cxl_rbuf_rd_done_s & (rbuf_fifo_af_s ? rbuf_fifo_re_s : 1'b1);
assign cxl_rbuf_restart_s  = cxl_rx_retry_req || ((r_state == CXL_RBUF_READ) && !cxl_rrsm_retry_req);


// ----------------------------------------------------------------------------
// Retry Buffer FSM
// ----------------------------------------------------------------------------
always_comb begin : next_state_proc
    unique case(r_state)
        // Retry Request to read from the retry buffer
        CXL_RBUF_READ : begin
            // If Retry.Req flit is received while RBUF replay is in progress then
            // transit back to CXL_RBUF_IDLE state to process new request
            if (cxl_rx_retry_req || !cxl_rrsm_retry_req)
                s_next_state = CXL_RBUF_IDLE;
            // Wait for all flits to be replayed, i.e. WrPtr=RdPtr
            else if (cxl_rbuf_retry_done)
                s_next_state = CXL_RBUF_DONE;
            else
                s_next_state = CXL_RBUF_READ;
        end
        CXL_RBUF_DONE : begin
            // Wait for RRSM to de-assert retry request to RBUF FSM
            if (cxl_rx_retry_req || !cxl_rrsm_retry_req)
                s_next_state = CXL_RBUF_IDLE;
            else
                s_next_state = CXL_RBUF_DONE;
        end
        default : begin // CXL_RBUF_IDLE
            if (cxl_rrsm_retry_req && !cxl_rbuf_retry_done)
                s_next_state = CXL_RBUF_READ;
            else
                s_next_state = CXL_RBUF_IDLE;
        end
    endcase
end : next_state_proc
// ----------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Instantiate FIFO controller
// -------------------------------------------------------------------------------------
assign rbuf_fifo_din_s   = rbuf_ram_rdata; 
assign rbuf_fifo_we_s    = cxl_rbuf_rd_vld_s & ~rbuf_fifo_full_s;
assign rbuf_fifo_re_s    = rbuf_fifo_valid_s & ~cxl_llctrl_rbuf_halt;
assign rbuf_fifo_valid_s = cxl_llctrl_rbuf_en & ~cxl_rbuf_retry_done & ~rbuf_fifo_empty_s;

DWC_pcie_ctl_bcm65_td
 #(
    .WIDTH            ( RBUF_DATA_WD        ),
    .DEPTH            ( 3                   ),
    .ADDR_WIDTH       ( 2                   ),
    .AE_LEVEL         ( 1                   ),
    .AF_LEVEL         ( RBUF_READ_LATENCY   ),
    .ERR_MODE         ( 0                   ),
    .RST_MODE         ( 0                   ),
    .REG_DELAY_TIME   ( 1                   ),
    .REG_DELAY_DENOM  ( 10                  )
) u_rbuf_fifo (
    .clk              ( core_clk            ),
    .rst_n            ( core_rst_n          ),
    .init_n           ( ~cxl_rbuf_restart_s ),
    .push_req_n       ( ~rbuf_fifo_we_s     ),
    .pop_req_n        ( ~rbuf_fifo_re_s     ),
    .diag_n           ( 1'b1                ),
    .data_in          ( rbuf_fifo_din_s     ),
    .empty            ( rbuf_fifo_empty_s   ),
    .almost_empty     (                     ),
    .half_full        (                     ),
    .almost_full      ( rbuf_fifo_af_s      ),
    .full             ( rbuf_fifo_full_s    ),
    .error            (                     ),
    .data_out         ( rbuf_fifo_dout_s    )
);

delay_n
 #(
    .N     (RBUF_READ_LATENCY),
    .WD    (1)
) u_delay_rbuf_rd_en (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (cxl_rbuf_restart_s),
    .din   (cxl_rbuf_rd_en),
    .dout  (cxl_rbuf_rd_vld_s)
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// RBUF Read Address Counter
// -------------------------------------------------------------------------------------
always_comb begin
    if (cxl_rx_retry_req)
        cxl_rbuf_rd_addr_nxt  = cxl_rx_eseq;
    else if (cxl_rbuf_rd_en) 
        cxl_rbuf_rd_addr_nxt  =  cxl_rbuf_rd_addr + 1;
    else
        cxl_rbuf_rd_addr_nxt  =  cxl_rbuf_rd_addr;
end
// -------------------------------------------------------------------------------------


always_ff @(posedge core_clk or negedge core_rst_n) begin : rbuf_reg_proc
    if (!core_rst_n) begin
        r_state           <= # TP CXL_RBUF_IDLE;
        cxl_rbuf_rd_addr  <= # TP '0;
    end else begin
        r_state           <= # TP s_next_state;
        cxl_rbuf_rd_addr  <= # TP cxl_rbuf_rd_addr_nxt;
    end
end : rbuf_reg_proc

endmodule
