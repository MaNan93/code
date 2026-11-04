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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_link_init_fsm.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL link layer initialization FSM this module is responsible for the link
// layer initialization process for CXL.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_link_init_fsm
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) 
                                          (
// Inputs ------------------------------------------------------------------------------
    input                                core_clk,               // Core clock
    input                                core_rst_n,             // Core reset
    input                                cxl_init_param_sent,    // Init.Param flit sent
    input                                cfg_init_stall,         // Stall link initialization
    input                                cfg_crd_stall,          // Stall credit initialization
    input [(CXL_VERSION_WD - 1) : 0]     cfg_cxl_version,        // CXL Version
    input [(ESEQ_WD - 1) : 0]            cfg_llr_wrap_value,     // Local Sequence number wrap value
    input [(ESEQ_WD - 1) : 0]            cfg_rx_rcvd_llr_wrap,   // Remote partner Sequence counter wrap value
    input                                cxl_pcie_flit_mode,     // CXL 256B Flit Mode
    input                                cxl_link_enable,        // CXL.cachemem protocol is enabled
    input                                cxl_vlsm_init_req,      // VLSM link initalization request
    input                                cxl_link_crd_ack,       // credit initialization done
    input                                cxl_rx_rcvd_init_param, // received init.param
    input                                cxl_rx_rcvd_retry,      // received retry flit
    input                                cxl_rx_rcvd_non_retry,  // non retry flit received
// Outputs -----------------------------------------------------------------------------
    output logic                         cxl_ll_init_param_uc,   // INIT.Param received after INIT.Param (Uncorrectable Error)
    output logic                         cxl_ll_non_retry_uc,    // Non-Retry Flit received before INIT.Param (Uncorrectable Error)
    output logic                         cxl_ll_init_crd_done,   // initialization done
    output logic                         cxl_ll_init_crd,        // request credit initialization
    output logic                         cxl_ll_init_done,       // Link Init - INIT.Param exchange done 
    output logic [(ESEQ_WD - 1) : 0]     cxl_ll_init_llr_wrap,   // Sequence counter wrap value
    output logic [(LL_CSR_STATE_WD-1):0] cxl_ll_init_state_reg,  // CXL LL Control and Status Register - Init State
    output logic                         cxl_init_param_req,     // Init.Param flit request
    output logic [63:0]                  cxl_init_param_payload  // Init.Param flit payload
);

// Declarations
init_state_e                       cxl_ll_init_state, init_state_nxt; // Link Initialization FSM
logic [(ESEQ_WD - 1) : 0]          s_ll_init_llr_wrap;                // LLR Wrap Value
logic                              rx_init_param_r, rx_init_param_s;  // Latch Init.Param received indication
logic [(LL_CSR_STATE_WD-1):0]      cxl_ll_init_state_nxt;             // 2-bit Link Init State as it appears in CXL LL Control and Status Register
logic [(CXL_VERSION_WD - 1) : 0]   cfg_cxl_version_s;                 // CXL3.0 Version: 0011 for 256B Flit mode, 0010 for 68B Flit mode

// FSM outputs
assign cxl_ll_init_crd_done   = (cxl_ll_init_state == CXL_INIT_DONE);
assign cxl_ll_init_crd        = (cxl_ll_init_state == CXL_INIT_CREDIT);
assign cxl_ll_init_done       = &cxl_ll_init_state_reg;

// Receipt of an LLCTRL-INIT.Param flit after an LLCTRL-INIT.Param flit has already
// been received should be considered an Uncorrectable Error.
assign cxl_ll_init_param_uc = cxl_rx_rcvd_init_param && rx_init_param_r;
// Any non-Retry flits received before LLCTRL-INIT.Param flit will trigger an
// Uncorrectable Error.
assign cxl_ll_non_retry_uc  = (cxl_rx_rcvd_non_retry && !cxl_rx_rcvd_init_param) && !rx_init_param_r;

// Latch the retry buffer wrap value
assign s_ll_init_llr_wrap = (cxl_rx_rcvd_init_param && !cxl_pcie_flit_mode) ? cfg_rx_rcvd_llr_wrap : cxl_ll_init_llr_wrap;

// Latch the Init.Param received indication
assign rx_init_param_s = cxl_rx_rcvd_init_param ? 1'b1 : rx_init_param_r;

// CXL3.0 Version: 0000 for 256B Flit mode, 0010 for 68B Flit mode
assign cfg_cxl_version_s = cxl_pcie_flit_mode ? cfg_cxl_version : 4'b0010;

// -------------------------------------------------------------------------------------
// Link Initialization FSM Next State
// -------------------------------------------------------------------------------------
always_comb begin : init_state_nxt_PROC
    init_state_nxt = cxl_ll_init_state;

    unique case(cxl_ll_init_state)
        CXL_WAIT_FLIT : begin
            // Wait until Init.Param or Retry flit is received
            // Stall Init.Param transmission if cfg_init_stall is asserted
            if (rx_init_param_s || cxl_rx_rcvd_retry || cxl_pcie_flit_mode)
                init_state_nxt = cfg_init_stall ? CXL_STALL_INIT : CXL_SEND_INIT_PARAM;
        end
        CXL_STALL_INIT : begin
            // Hold here until LL_Init_Stall is set to 0 or
            // Link Initialization is not requested by Link vLSM
            if (!cfg_init_stall && cxl_vlsm_init_req)
                init_state_nxt = CXL_SEND_INIT_PARAM;
        end
        CXL_SEND_INIT_PARAM : begin
            // Wait until Init.Param has been transmitted
            if (cxl_init_param_sent)
                init_state_nxt = CXL_WAIT_INIT_PARAM;
        end
        CXL_WAIT_INIT_PARAM : begin
            // Wait until Init.Param is received
            // Stall credit initialization if cfg_crd_stall is asserted
            if (rx_init_param_s)
                init_state_nxt = cfg_crd_stall ? CXL_STALL_INIT_CREDIT : CXL_INIT_CREDIT;
        end
        CXL_STALL_INIT_CREDIT : begin
            // Hold here until LL_Crd_Stall is set to 0
            if (!cfg_crd_stall)
                init_state_nxt = CXL_INIT_CREDIT;
        end
        CXL_INIT_CREDIT : begin
            // Credit initialization complete
            if (cxl_link_crd_ack)
                init_state_nxt = CXL_INIT_DONE;
        end
        CXL_INIT_DONE : begin
            // Remain in CXL_INIT_DONE until VLSM transitions out of the ACTIVE state
            init_state_nxt = CXL_INIT_DONE;
        end
        default : begin // INIT_IDLE
            // If CXL.cachemem link is enabled then wait for Link Initialization
            if (cxl_link_enable) init_state_nxt = cxl_pcie_flit_mode ? CXL_STALL_INIT : CXL_WAIT_FLIT;
        end
    endcase
end : init_state_nxt_PROC

// -------------------------------------------------------------------------------------
// 2-bit Link Init State as it appears in CXL LL Control and Status Register
// -------------------------------------------------------------------------------------
always_comb begin
    unique case(init_state_nxt)
        // 00 --> NOT_RDY_FOR_INIT (stalled or unstalled): LLCTRLINIT. Param flit not sent
        CXL_INIT_IDLE        : cxl_ll_init_state_nxt = 2'b00;
        // 01 --> PARAM_EX: LLCTRL-INIT.Param sent and waiting to receive it
        CXL_WAIT_INIT_PARAM  : cxl_ll_init_state_nxt = 2'b01;
        // 10 --> CRD_RETURN_STALL: Parameter exchanged successfully and Credit return is stalled
        CXL_STALL_INIT_CREDIT: cxl_ll_init_state_nxt = 2'b10;
        // 11 --> INIT_DONE: Link Initialization Done - LLCTRLINIT.
        // Param flit sent and received, and initial credit refund not stalled
        CXL_INIT_CREDIT,
        CXL_INIT_DONE        : cxl_ll_init_state_nxt = 2'b11;
        default              : cxl_ll_init_state_nxt = cxl_ll_init_state_reg;
    endcase
end

// -------------------------------------------------------------------------------------
// Init.Param Flit Generation
// -------------------------------------------------------------------------------------
always_comb begin : init_flit_proc
    if (cxl_ll_init_state == CXL_SEND_INIT_PARAM) begin
        cxl_init_param_req     = 1'b1;
        cxl_init_param_payload = {32'd0, cxl_pcie_flit_mode ? {ESEQ_WD{1'b0}} : cfg_llr_wrap_value, 20'd0, cfg_cxl_version_s};
    end
    else begin
        cxl_init_param_req     = 1'b0;
        cxl_init_param_payload = 64'd0;
    end
end : init_flit_proc

always_ff @(posedge core_clk or negedge core_rst_n) begin : init_state_proc
    if (!core_rst_n) begin
        cxl_ll_init_state       <= # TP CXL_INIT_IDLE;
        cxl_ll_init_state_reg   <= # TP 2'b00;
        cxl_ll_init_llr_wrap    <= # TP 8'h09;
        rx_init_param_r         <= # TP 1'b0;
    end else begin
        cxl_ll_init_state       <= # TP init_state_nxt;
        cxl_ll_init_state_reg   <= # TP cxl_ll_init_state_nxt;
        cxl_ll_init_llr_wrap    <= # TP s_ll_init_llr_wrap;
        rx_init_param_r         <= # TP rx_init_param_s;
    end
end : init_state_proc

endmodule
