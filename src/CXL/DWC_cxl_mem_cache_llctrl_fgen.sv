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
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_llctrl_fgen.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Link Layer Control Flit Generator for 68B flits
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_llctrl_fgen
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
)
                                        (
// Inputs ------------------------------------------------------------------------------
    input                                         core_clk,
    input                                         core_rst_n,
    input                                         cxl_pcie_flit_mode,         // CXL 256B Flit Mode
    input                                         cxl_llctrl_halt,          // LLCTRL Flit Halt
    input                                         cxl_retry_normal,         // LRSM and RRSM are in Normal state
    input                                         cxl_retryable_flit_ena,   // Enable retryable flit based on RBUF NumFreeBuf
    input                                         cxl_hdr_ack_bit,          // Credit Controller - Flit Header Ack Bit
    input  [(FLIT_CRD_WD - 1) : 0]                cxl_hdr_data_crd,         // Credit Controller - Flit Header Data Credits
    input  [(FLIT_CRD_WD - 1) : 0]                cxl_hdr_rsp_crd,          // Credit Controller - Flit Header Response Credits
    input  [(FLIT_CRD_WD - 1) : 0]                cxl_hdr_req_crd,          // Credit Controller - Flit Header Request Credits
    input                                         cxl_init_param_req,       // INIT requests Init.Param sequence
    input  [63:0]                                 cxl_init_param_payload,   // INIT requests Init.Param payload
    input                                         cxl_rbuf_retry_req,       // Retry Buffer is offloading
    input                                         cxl_lrsm_retry_req,       // LRSM requests Retry.Req sequence
    input  [63:0]                                 cxl_lrsm_retry_payload,   // LRSM requests Retry.Req payload
    input                                         cxl_lrsm_idle_req,        // LRSM requests Retry.Idle flit
    input                                         cxl_rrsm_retry_ack,       // RRSM requests Retry.Ack sequence
    input  [63:0]                                 cxl_rrsm_retry_payload,   // RRSM requests Retry.Ack payload
    input                                         cxl_llcrd_req,            // CRD requests LLCRD sequence
    input  [63:0]                                 cxl_llcrd_payload,        // CRD requests LLCRD payload
// Outputs -----------------------------------------------------------------------------
    output logic                                  cxl_init_param_sent,      // INIT Init.Param sent
    output logic                                  cxl_lrsm_retry_req_sent,  // LRSM Retry.Req sent
    output logic                                  cxl_rrsm_retry_ack_sent,  // RRSM Retry.Ack sent
    output logic                                  cxl_llcrd_sent,           // INIT LLCRD sent
    output logic                                  cxl_llctrl_flit_valid,    // LLCTRL Flit valid
    output logic                                  cxl_llctrl_flit_sof,      // LLCTRL Flit Start of Flit`
    output logic                                  cxl_llctrl_flit_eof,      // LLCTRL Flit End of Flit
    output logic [127:0]                          cxl_llctrl_flit           // LLCTRL FLIT 
);

// LLCTRL Flit Generation FSM States
typedef enum logic [6:0] {
    FGEN_IDLE         = 7'b000_0001,
    FGEN_INIT_PARAM   = 7'b000_0010,
    FGEN_RETRY_IDLE   = 7'b000_0100,
    FGEN_RETRY_FRAME  = 7'b000_1000,
    FGEN_RETRY_REQ    = 7'b001_0000,
    FGEN_RETRY_ACK    = 7'b010_0000,
    FGEN_LLCRD_ACK    = 7'b100_0000
} llctrl_state_t;

// Declarations
llctrl_state_t    llctrl_state_r, llctrl_state_nxt;          // LLCTRL Flit Generation FSM
logic [31:0]      llcrd_flit_hdr_s;                          // LLCRD Link Control Flit Header
logic [2:0]       retry_frame_cntr_r, retry_frame_cntr_nxt;  // 5 Retry.Frame sequence counter
logic             retry_frame_done_s;                        // 5 Retry.Frame sequence completed
logic             retry_frame_rst_s;                         // 5 Retry.Frame sequence reset
logic             cxl_lrsm_retry_frame_sent;                 // LRSM Retry.Frame sent

assign cxl_lrsm_retry_frame_sent = (llctrl_state_r == FGEN_RETRY_FRAME) && !cxl_llctrl_halt && cxl_llctrl_flit_eof;
assign cxl_lrsm_retry_req_sent   = (llctrl_state_r == FGEN_RETRY_REQ  ) && !cxl_llctrl_halt && cxl_llctrl_flit_eof;
assign cxl_rrsm_retry_ack_sent   = (llctrl_state_r == FGEN_RETRY_ACK  ) && !cxl_llctrl_halt && cxl_llctrl_flit_eof;
assign cxl_init_param_sent       = (llctrl_state_r == FGEN_INIT_PARAM ) && !cxl_llctrl_halt && cxl_llctrl_flit_eof;
assign cxl_llcrd_sent            = (llctrl_state_r == FGEN_LLCRD_ACK  ) && !cxl_llctrl_halt && cxl_llctrl_flit_eof;

localparam ARBMUX_WD_RATIO = 2048 / ARBMUX_DATA_WD ;

logic [ARBMUX_WD_RATIO-1:0] llctrl_dv_cntr_r, llctrl_dv_cntr_nxt;

// -------------------------------------------------------------------------------------
// Retry.Frame sequence counter
// -------------------------------------------------------------------------------------
assign cxl_llctrl_flit_sof = cxl_pcie_flit_mode ? &llctrl_dv_cntr_r              : cxl_llctrl_flit_valid;
assign cxl_llctrl_flit_eof = cxl_pcie_flit_mode ? llctrl_dv_cntr_r[1:0] == 2'b01 : cxl_llctrl_flit_valid;

always_comb begin
    if (cxl_pcie_flit_mode && (llctrl_state_r == FGEN_IDLE) && (llctrl_state_nxt != FGEN_IDLE)) begin
        llctrl_dv_cntr_nxt = {ARBMUX_WD_RATIO{1'b1}};
    end
    else if (!cxl_llctrl_halt) begin
        llctrl_dv_cntr_nxt = llctrl_dv_cntr_r >> 1;
    end
    else begin
        llctrl_dv_cntr_nxt = llctrl_dv_cntr_r;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Retry.Frame sequence counter
// -------------------------------------------------------------------------------------
assign retry_frame_done_s = cxl_lrsm_retry_frame_sent && (retry_frame_cntr_r == 3'b100);
assign retry_frame_rst_s  = !cxl_lrsm_retry_req && !cxl_rrsm_retry_ack;

always_comb begin
    if (retry_frame_done_s || retry_frame_rst_s) begin
        retry_frame_cntr_nxt = 3'd0;
    end
    else if (cxl_lrsm_retry_frame_sent) begin
        retry_frame_cntr_nxt = retry_frame_cntr_r + 3'd1;
    end
    else begin
        retry_frame_cntr_nxt = retry_frame_cntr_r;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// LLCTRL Flit Formation
//  68B Flit Format: 32-bit FLit Header, 4-bit LLCTRL, 4-bit SubType, 24-bit reserved, 64-bit Payload
// 256B Flit Format: 2 byte Flit Header, 4-bit Slot Format (H8), 4-bit LLCTRL, 4-bit SubType, 4-bit Reserved, 96-bit Payload
// -------------------------------------------------------------------------------------
assign llcrd_flit_hdr_s = {cxl_hdr_data_crd, cxl_hdr_req_crd, cxl_hdr_rsp_crd, 1'b0           , 16'd0, cxl_hdr_ack_bit, 1'b0, 1'b1};

always_comb begin
    case (llctrl_state_r)
        FGEN_IDLE      : cxl_llctrl_flit_valid = 1'b0;
        // Prevents sending dummy LLCRD flit in the last cycle during Credit Initialization when
        // LLCRD flits are transmitted back-2-back
        FGEN_LLCRD_ACK : cxl_llctrl_flit_valid = cxl_llcrd_req;
        default        : cxl_llctrl_flit_valid = 1'b1;
    endcase
end

always_comb begin
    if (cxl_llctrl_flit_sof) begin
        case (llctrl_state_r)
            FGEN_INIT_PARAM  : cxl_llctrl_flit = cxl_pcie_flit_mode ? {32'd0, cxl_init_param_payload, 4'd0, LLCTRL_INIT_PARAM , LLCTRL_INIT, 4'h8, 16'h0080} :
                                                 {cxl_init_param_payload, 24'd0, LLCTRL_INIT_PARAM , LLCTRL_INIT , 24'd0, 8'd1};
            FGEN_RETRY_IDLE  : cxl_llctrl_flit = {64'd0                 , 24'd0, LLCTRL_RETRY_IDLE , LLCTRL_RETRY, 24'd0, 8'd1};
            FGEN_RETRY_FRAME : cxl_llctrl_flit = {64'd0                 , 24'd0, LLCTRL_RETRY_FRAME, LLCTRL_RETRY, 24'd0, 8'd1};
            FGEN_RETRY_REQ   : cxl_llctrl_flit = {cxl_lrsm_retry_payload, 24'd0, LLCTRL_RETRY_REQ  , LLCTRL_RETRY, 24'd0, 8'd1};
            FGEN_RETRY_ACK   : cxl_llctrl_flit = {cxl_rrsm_retry_payload, 24'd0, LLCTRL_RETRY_ACK  , LLCTRL_RETRY, 24'd0, 8'd1};
            FGEN_LLCRD_ACK   : cxl_llctrl_flit = {cxl_llcrd_payload     , 24'd0, LLCTRL_LLCRD_ACK  , LLCTRL_LLCRD, llcrd_flit_hdr_s};
            default          : cxl_llctrl_flit = 128'd0;
        endcase
    end
    else cxl_llctrl_flit = 128'd0;
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// LLCTRL Flit Generation FSM
// -------------------------------------------------------------------------------------
always_comb begin
    case (llctrl_state_r)
        FGEN_INIT_PARAM: begin
            if (!cxl_llctrl_halt && cxl_llctrl_flit_eof) begin
                llctrl_state_nxt = FGEN_IDLE;
            end
            else begin
                llctrl_state_nxt = llctrl_state_r;
            end
        end
        FGEN_LLCRD_ACK: begin
            if (cxl_llcrd_req && !cxl_llctrl_halt) begin
                llctrl_state_nxt = FGEN_LLCRD_ACK;
            end
            else if (!cxl_llcrd_req) begin
                llctrl_state_nxt = FGEN_IDLE;
            end
            else begin
                llctrl_state_nxt = llctrl_state_r;
            end
        end
        FGEN_RETRY_IDLE: begin
            // If Retry.Ack is requested during Retry.Idle period implied by the Retry.Req then
            // temporary transit to RETRY_ACK to transmit Retry.Ack sequence
            if (cxl_rrsm_retry_ack) begin
                llctrl_state_nxt = FGEN_RETRY_FRAME;
            end
            // Stay in RETRY_IDLE for as long as Retry.Idle request is asserted
            else if (cxl_lrsm_idle_req) begin
                llctrl_state_nxt = llctrl_state_r;
            end
            // If Retry.Idle requests is de-asserted then move to the IDLE state
            else begin
                llctrl_state_nxt = FGEN_IDLE;
            end
        end
        FGEN_RETRY_FRAME: begin
            if ((cxl_lrsm_retry_req || cxl_rrsm_retry_ack) && retry_frame_done_s && !cxl_llctrl_halt) begin
                // If Retry.Ack is asserted then move to RETRY_ACK. Must give a priority to Retry.Ack.
                if (cxl_rrsm_retry_ack) begin
                    llctrl_state_nxt = FGEN_RETRY_ACK;
                end
                // If Retry.Req is asserted then move to RETRY_REQ state
                else if (cxl_lrsm_retry_req) begin
                    llctrl_state_nxt = FGEN_RETRY_REQ;
                end
                // If Retry.Req and Retry.Ack requests are de-asserted then return to the IDLE state
                else begin
                    llctrl_state_nxt = FGEN_IDLE;
                end
            end
            // If Retry.Req and Retry.Ack requests are de-asserted then return to the IDLE state
            else if (!cxl_lrsm_retry_req && !cxl_rrsm_retry_ack) begin
                llctrl_state_nxt = FGEN_IDLE;
            end
            else begin
                llctrl_state_nxt = llctrl_state_r;
            end
        end
        FGEN_RETRY_ACK  : begin
            // If Retry.Ack is sent then move to the IDLE state
            if (cxl_rrsm_retry_ack && !cxl_llctrl_halt) begin
                llctrl_state_nxt = FGEN_IDLE;
            end
            // If Retry.Ack request is de-asserted then move to the IDLE state
            else if (!cxl_rrsm_retry_ack) begin
                llctrl_state_nxt = FGEN_IDLE;
            end
            else begin
                llctrl_state_nxt = llctrl_state_r;
            end
        end
        FGEN_RETRY_REQ  : begin
            // If Retry.Req is sent then move to the RETRY_IDLE state to
            // start transmitting Retry.Idle frames
            if (cxl_lrsm_retry_req && !cxl_llctrl_halt) begin
                llctrl_state_nxt = FGEN_RETRY_IDLE;
            end
            // If Retry.Req request is de-asserted then move to the IDLE state
            else if (!cxl_lrsm_retry_req) begin
                llctrl_state_nxt = FGEN_IDLE;
            end
            else begin
                llctrl_state_nxt = llctrl_state_r;
            end
        end
        default: begin // FGEN_IDLE
            // Select LLCTRL Flit to transmit based on their priority
            if (cxl_pcie_flit_mode) begin
                // Only INIT.PARAM LLCTRL flits are applicable to CXL3.0
                // InbandError flits are generated at Physical Layer
                if (cxl_init_param_req) begin
                    llctrl_state_nxt = FGEN_INIT_PARAM;
                end
                else begin
                    llctrl_state_nxt = llctrl_state_r;
                end
            end
            else
            // Do not allow Retry.Req flits from LRSM after Retry.Ack
            if ((cxl_lrsm_retry_req && !cxl_rbuf_retry_req) || cxl_rrsm_retry_ack) begin
                llctrl_state_nxt = FGEN_RETRY_FRAME;
            end
            else
            // Allow INIT.PARAM flits when both LRSM and RRSM are in NORMAL state
            if (cxl_init_param_req && cxl_retry_normal) begin
                llctrl_state_nxt = FGEN_INIT_PARAM;
            end
            // Allow LLCRD flits when both LRSM and RRSM are in NORMAL state and
            // there is enough space in the Retry Buffer (cxl_retryable_flit_ena)
            else if (cxl_llcrd_req && cxl_retry_normal && cxl_retryable_flit_ena) begin
                llctrl_state_nxt = FGEN_LLCRD_ACK;
            end
            // Do not allow Retry.Idle flits from LRSM after Retry.Ack
            else if (cxl_lrsm_idle_req && !cxl_rbuf_retry_req) begin
                llctrl_state_nxt = FGEN_RETRY_IDLE;
            end
            else begin
                llctrl_state_nxt = llctrl_state_r;
            end
        end
    endcase
end
// -------------------------------------------------------------------------------------

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        llctrl_state_r     <= # TP FGEN_IDLE;
        retry_frame_cntr_r <= # TP 3'd0;
        llctrl_dv_cntr_r   <= # TP '0;
    end else begin
        llctrl_state_r     <= # TP llctrl_state_nxt;
        retry_frame_cntr_r <= # TP retry_frame_cntr_nxt;
        llctrl_dv_cntr_r   <= # TP llctrl_dv_cntr_nxt;
    end
end

endmodule
