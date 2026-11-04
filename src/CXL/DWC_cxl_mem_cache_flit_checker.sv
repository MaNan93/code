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
// ---   $Revision: #12 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_flit_checker.sv#12 $
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Design Ware Core's CXL Controller RX Flit Checker, which implements the part of the RX link layer requirement of the CXL specification.
// ---    Performs CRC check on the received flit
// ---    Extracts the Flit header
// ---        Checks type of the flit.
// ---        Communicates received credits to TX layer
// ---        Communicates received acknowledgement to Link layer control block.
// ---    Allows flit decoding through unpacker or link layer control block.
// ---    Controls Flit decoding based on CRC error and recovery.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"

module DWC_cxl_mem_cache_flit_checker
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) 
                                         (
// Interfaces --------------------------------------------------------------------------
// Inputs ------------------------------------------------------------------------------
    input                                       core_clk                      , // Core Clock
    input                                       core_rst_n                    , // Core Active Low Reset
    input                                       cxl_pcie_flit_mode            , // CXL 256B Flit Mode
    // RX ARB/MUX IF
    input                                       cxl_arb_mem_cache_valid       , // ARB/MUX CXL Flit Valid
    input  [ARBMUX_FLIT_WD-1:0]                 cxl_arb_mem_cache_data        , // ARB/MUX CXL Flit Data
    input  [MAX_RX_CRC_ERROR_WD-1:0]            cxl_rx_max_crc_error          , // CRC Error thresold value
    input                                       cxl_lrsm_drop_flits           , // LRSM is active this means all received non LLCTRL retry flits must be discarded
    // RX Protocol IF with RX unpacker
    input                                       cxl_rx_unpack_flit_prot_adf   , // RX Unpacker Protocol Flit ADF
    input                                       cxl_rx_unpack_ras_dp_err      , // CXL RX RAS DP Uncorrectable Error
// Outputs -----------------------------------------------------------------------------
    output logic                                chi_rx_unpack_flit_prot_en    , // RX Unpacker Protocol Flit Valid (Native Unpacker)
    output logic                                cxl_rx_unpack_flit_error      , // RX Unpacker Protocol Flit CRC Error
    output logic [ARBMUX_DATA_WD-1:0]           cxl_rx_unpack_flit_data       , // RX Unpacker Flit Data
    // RX LLCTRL IF with RX Link Controller for Link Flow Control
    output logic                                cxl_rx_llctrl_flit_ctrl_en    , // RX LLCTRL Control Flit Valid
    output logic                                cxl_rx_llctrl_flit_prot_en    , // RX LLCTRL Protocol Flit Valid
    output logic                                cxl_rx_llctrl_flit_prot_adf   , // RX LLCTRL Protocol Flit ADF
    output logic [127:0]                        cxl_rx_llctrl_flit_data       , // RX LLCTRL Flit Data
    output logic [15:0]                         cxl_rx_crd_flit_data          , // RX CRD Flit Data
    // RX Flit IF with RX Link Controller for Retry Flow Control
    output logic                                cxl_rx_crc_flit_valid         , // RX Flit Valid after CRC check
    output logic [ARBMUX_DATA_WD-1:0]           cxl_rx_crc_flit_data          , // RX Flit Data after CRC check
    output logic                                cxl_rx_crc_flit_error         , // Indicates that received flit has crc error 
    output logic                                cxl_rx_crc_error              , // Indicates that received flit has crc error 
    output logic                                cxl_tl_rx_crc_error           , // CRC Error to Transaction Layer
    output logic                                cxl_rx_crc_error_hit          // CRC Error thresold hit

);

// Local parameters
localparam CRD_256B_FLIT_INDEX = (CXL_DATA_WD == 1024) ? 128*7 : 128*3;

// Local wires and regs
logic                            cxl_rx_flit_type;          // Flit Header Type field: 0 - Protocol; 1 - Control
logic   [3:0]                    cxl_rx_ctrl_type;          // Link Layer Control Flit Type field
logic                            cxl_rx_retriable_flit_s;   // Retryable Flit Received
logic                            cxl_rx_crc_error_s;        // Internal RX CRC Error
logic                            cxl_rx_crc_flit_halt;      // ARB/MUX Interface Backpressure by IDE or CXS interface (drop flits)

logic   [15:0]                   cxl_flit_data_crc;         // Received Flit Data CRC
logic                            cxl_flit_data_crc_error;   // Received Flit Data CRC Error

logic                            cxl_flit_valid;            // CXL Flit Valid after CRC check and LRSM drop flits
logic   [ARBMUX_DATA_WD-1:0]     cxl_flit_data;             // CXL Flit Data after CRC check and LRSM drop flits
logic   [15:0]                   cxl_flit_data_chk;         // CXL Flit Data CRC 
logic                            cxl_flit_nocrc_valid;      // CXL Flit Valid before CRC check and after LRSM drop flits



// ---------------------------------------------------------------------------------
// Signals will be output only if RAS is enabled 
// ---------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// CXL Flit IF after LRSM Drop Flits
// -------------------------------------------------------------------------------------
assign cxl_flit_valid           = cxl_rx_crc_flit_valid && !cxl_lrsm_drop_flits ;
assign cxl_flit_data            = cxl_rx_crc_flit_data;
assign cxl_flit_data_chk        = cxl_arb_mem_cache_data[ARBMUX_68B_DATA_WD+:16];
assign cxl_flit_nocrc_valid     = cxl_arb_mem_cache_valid && !cxl_lrsm_drop_flits;

// Decode the incoming flit type by ADF indication from the Flit Unpacker and the Type field.
assign cxl_rx_flit_type         = cxl_rx_unpack_flit_prot_adf ? 1'b0 : cxl_flit_data[0];
assign cxl_rx_ctrl_type         = cxl_flit_data[35:32];

// CRC - RX Flit Valid
assign cxl_rx_crc_flit_valid    = cxl_arb_mem_cache_valid && !cxl_rx_crc_error_s;
assign cxl_rx_crc_flit_data     = cxl_arb_mem_cache_data[ARBMUX_DATA_WD-1:0];
assign cxl_rx_crc_flit_error    = cxl_rx_crc_error_s;

// CRC Error Indication to Link Retry FSM
assign cxl_rx_retriable_flit_s  = cxl_arb_mem_cache_valid && (cxl_rx_flit_type ? (cxl_rx_ctrl_type != LLCTRL_RETRY) : 1'b1);
assign cxl_rx_crc_flit_halt     = 1'b0 ;
assign cxl_rx_crc_error_s       = ( cxl_flit_data_crc_error || cxl_rx_crc_flit_halt) && !cxl_pcie_flit_mode;

assign cxl_rx_crc_error         = cxl_rx_crc_error_s;


// -------------------------------------------------------------------------------------
// CXL Protocol Flit Interface 
// For native interface unpacker must use valid signal before CRC check for timing purpose.
// Corrupted flits are dropped later at the transaction layer in this case.
// -------------------------------------------------------------------------------------
logic                            chi_unpack_flit_valid;            // CXL IDE Disable Mux Output -Flit Valid
logic                            cxs_unpack_flit_valid;            // CXL IDE Disable Mux Output -Flit Valid
logic [ARBMUX_DATA_WD-1:0]       cxl_unpack_flit_data;             // CXL IDE Disable Mux Output -Flit Data
logic                            cxl_unpack_flit_adf;              // CXL IDE Disable Mux Output -Flit ADF

logic                            cxl_unpack_flit_type;             // Flit Header Type field: 0 - Protocol; 1 - Control

logic                            cxl_unpack_sof;
logic                            cxl_rx_unpack_flit_valid;

// Flit Protocol Interface - If IDE is enabled then use IDE RX Plain IF
assign chi_unpack_flit_valid       = cxl_flit_nocrc_valid;
assign cxl_unpack_flit_data        = cxl_flit_data;
assign cxl_unpack_flit_adf         = cxl_rx_unpack_flit_prot_adf;
assign cxl_unpack_sof              = !cxl_unpack_flit_adf;
assign cxl_unpack_flit_type        = cxl_pcie_flit_mode ? 1'b0 : (cxl_unpack_flit_adf ? 1'b0 : cxl_unpack_flit_data[0]);

assign chi_rx_unpack_flit_prot_en  = chi_unpack_flit_valid && !cxl_unpack_flit_type;
assign cxl_rx_unpack_flit_data     = cxl_unpack_flit_data;
assign cxl_rx_unpack_flit_valid    = cxl_rx_crc_flit_valid;
assign cxl_rx_unpack_flit_error    = cxl_rx_crc_error || cxl_rx_unpack_ras_dp_err;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// LLCTRL Flow Control Interface 
// -------------------------------------------------------------------------------------

logic                            cxl_llctrl_flit_valid;            // CXL IDE Disable Mux Output - Flit Valid
logic [127:0]                    cxl_llctrl_flit_data;             // CXL IDE Disable Mux Output - Flit Data
logic                            cxl_llctrl_flit_adf;              // CXL IDE Disable Mux Output - Flit ADF
logic                            cxl_llctrl_flit_type;             // Flit Header Type field: 0 - Protocol; 1 - Control
logic [3:0]                      cxl_llctrl_ctrl_type;             // Link Layer Control Flit Type field
logic                            cxl_llctrl_non_retry;             // Link Layer Control Flit is not of Retry type

// Flit LLCTRL Interface - If IDE is enabled then use pipeline register output
// Drop flits on the pipeline register output if either CRC error is detected or LRSM directs to start dropping the flits
assign cxl_llctrl_flit_valid       = cxl_flit_valid;
assign cxl_llctrl_flit_data        = cxl_flit_data[127:0];
assign cxl_llctrl_flit_adf         = cxl_rx_unpack_flit_prot_adf;

assign cxl_llctrl_flit_type        = cxl_llctrl_flit_adf ? 1'b0 : cxl_llctrl_flit_data[0];
assign cxl_llctrl_ctrl_type        = cxl_llctrl_flit_data[35:32];
assign cxl_llctrl_non_retry        = cxl_llctrl_flit_type && (cxl_llctrl_ctrl_type != LLCTRL_RETRY);

// In 256B Flit mode disable the datapath to RX Link Controller as the Flit Unpacker handles LLCTRL flit extraction from H8 slot format
assign cxl_rx_llctrl_flit_ctrl_en  = cxl_llctrl_flit_valid && cxl_llctrl_non_retry && !cxl_pcie_flit_mode;
assign cxl_rx_llctrl_flit_prot_en  = (cxl_pcie_flit_mode)? cxl_rx_unpack_flit_valid : cxl_llctrl_flit_valid && !cxl_llctrl_flit_type ;
assign cxl_rx_llctrl_flit_prot_adf = cxl_llctrl_flit_adf;
assign cxl_rx_llctrl_flit_data     = (cxl_pcie_flit_mode)? cxl_rx_unpack_flit_data[127:0] : cxl_llctrl_flit_data;
assign cxl_rx_crd_flit_data        = (cxl_pcie_flit_mode)? cxl_rx_unpack_flit_data[CRD_256B_FLIT_INDEX +: 16] :  '0;
// -------------------------------------------------------------------------------------




// -------------------------------------------------------------------------------------
// CRC Checker & CRC Error Threshold Counter
// -------------------------------------------------------------------------------------
assign cxl_flit_data_crc_error  =   cxl_arb_mem_cache_valid && (cxl_flit_data_crc != cxl_flit_data_chk) && !cxl_pcie_flit_mode;

// Instantiate CRC Calcultor
DWC_cxl_mem_cache_crc
 U_DWC_cxl_mem_cache_crc (
    .cxl_flit_data_i             (cxl_arb_mem_cache_data[ARBMUX_68B_DATA_WD-1:0]),
    .cxl_crc_data_o              (cxl_flit_data_crc)
);

delay_n
 #(
    .N     (1),
    .WD    (1)
) u_rx_crc_error_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (cxl_rx_unpack_flit_error),
    .dout  (cxl_tl_rx_crc_error)
);

// CRC Error Counter
DWC_cxl_base_timer
 #(
    .TIMER_WIDTH  (MAX_RX_CRC_ERROR_WD)
) u_num_crc_err_count (
    // Inputs
    .clk          (core_clk),
    .rst_n        (core_rst_n),
    .clear_timer  (1'b0), 
    .hold_timer   (1'b0),
    .enable       (cxl_flit_data_crc_error & (|cxl_rx_max_crc_error)),
    .timer_target (cxl_rx_max_crc_error),
    .incr         ({{(MAX_RX_CRC_ERROR_WD-1){1'b0}},1'b1}),
    // Outputs
    .timeout_r    (),
    .timeout      (cxl_rx_crc_error_hit),
    .timer_r      ()
);
// -------------------------------------------------------------------------------------

endmodule
