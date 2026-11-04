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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_almp_dec.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Received ALMP Decoder
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_almp_dec
  import spif_pkg::*;                                  // Import SPIF package
  import DWC_cxl_pkg::*;
  import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter TP              = `TP
) 
                         (
  // Interfaces
  spif_if.rplh_slave_mp  b_rplh_spif,                  // RPLH SPIF Interface
  // Inputs
  input                  core_clk,
  input                  core_rst_n,
  input                  cxl_device_type,              // CXL Device type
  // Interface with LTSSM
  input                  cxl_pcie_flit_mode,           // CXL 256B Flit Mode
  input                  cxl_link_up,                  // CXL Link up indication from LTSSM
  // ALMP RX Interface with RMLH
  input                  almp_rx_en,                   // Enable Receive path
  input  ras_dp_err_inj_t ras_dp_err_inj,              // Rx ALMP checker RASDP error injection
  output ras_dp_err_log_t rx_almp_rasdp_err_log,       // Rx ALMP checker RASDP error log
  output logic           almp_rx_repl_error,           // ALMP replication error
  output                 almp_tx_en,                   // Enable ALMP Transmit path
  // ALMP Decoder interface with CXL.io ALMP Generator
  output logic           almp_io_rx_request,           // CXL.io Request ALMP Received
  output logic           almp_io_rx_status,            // CXL.io Status ALMP Received
  output state_enc_e     almp_io_rx_link_state,        // CXL.io Received VLSM state
  // ALMP Decoder interface with CXL.cache/mem ALMP Generator
  output logic           almp_mc_rx_request,           // CXL.cache/mem Request ALMP Received
  output logic           almp_mc_rx_status,            // CXL.cache/mem Status ALMP Received
  output state_enc_e     almp_mc_rx_link_state         // CXL.cache/mem Received VLSM state
);


// -------------------------------------------------------------------------------------
// Flit Accumulation Logic - accumulates flit on the SPIF interface
// -------------------------------------------------------------------------------------
logic                     rx_almp_buff_dv_s;
logic [127:0]             rx_almp_buff_data_s;
logic                     rx_almp_buff_chk_in_dv_s;     // RX ALMP gated input dv
logic [15:0]              rx_almp_buff_data_chk_s;      // RX ALMP data protection code
logic                     rx_almp_rasdp_dv_s;           // RX ALMP checker dv output
logic [31:0]              rx_almp_rasdp_data_s;         // RX ALMP checker data output
logic                     rx_almp_rasdp_err_s;          // RX ALMP rasdp_err output
// Preserved these signals and ALMP replication for the testbench only!!! To be removed!!!
logic                     rmlh_cxl_almp_dv;             // ALMP received
logic [127:0]             rmlh_cxl_almp_data;           // ALMP data
logic [127:0]             rmlh_cxl_almp_data_s;         // ALMP data

assign rmlh_cxl_almp_data = cxl_pcie_flit_mode ? {4{rmlh_cxl_almp_data_s[31:0]}} : rmlh_cxl_almp_data_s;

rplh_flit_buff
 #(
    .FLIT_OUT_REG       ( `CX_ARB_ALMP_DEC_REGIN    ), // Register received ALMP if there is no output register in RPLH
    .FLIT_WIDTH         ( 2048                      ), // Buffer entire 256B flit
    .STREAM_ID          ( SID_ALMP                  ), // Filter ALMP flits from the stream
    .LL_NBYTES          ( 16                        )  // Link Layer data width in bytes
) u_flit_buff (
    // Interfaces
    .b_rplh_spif        ( b_rplh_spif               ),
    // Inputs
    .core_clk           ( core_clk                  ),
    .core_rst_n         ( core_rst_n                ),
    .pcie_flit_mode     ( cxl_pcie_flit_mode        ),
    .rplh_buff_enable   ( 1'b1                      ),
    // Outputs
    .rx_flit_valid      ( rx_almp_buff_dv_s         ),
    .rx_flit_data       ( rx_almp_buff_data_s       ),
    .rx_flit_data_chk   ( rx_almp_buff_data_chk_s   ),
    .rx_crc_valid       ( /* Unconnected  */        ),
    .rx_crc_data        ( /* Unconnected  */        )
);
// -------------------------------------------------------------------------------------


// Enable Transmit/Recive path for ALMP Generator
logic [3:0] almp_rx_repl_check_s;           // ALMP replication error
logic       almp_rx_repl_error_s;           // ALMP replication error
logic       almp_rx_repl_error_nxt;         // ALMP replication error
logic       almp_tx_en_r, almp_tx_en_nxt;   // Enable Transmit path after fresh boot
almp_struct rx_almp_data_s;                 // Received ALMP Structure

// -------------------------------------------------------------------------------------
// Check 1DW ALMP message for replication error
// -------------------------------------------------------------------------------------
assign almp_rx_repl_error_s = (|almp_rx_repl_check_s) && !cxl_pcie_flit_mode;

assign almp_rx_repl_error = almp_rx_en && rmlh_cxl_almp_dv && almp_rx_repl_error_s;

always_comb begin
    almp_rx_repl_check_s[0] = |(rmlh_cxl_almp_data[15:0] ^ 16'h0800);
    almp_rx_repl_check_s[1] = |(rmlh_cxl_almp_data[31:0] ^ rmlh_cxl_almp_data[ 63:32]);
    almp_rx_repl_check_s[2] = |(rmlh_cxl_almp_data[31:0] ^ rmlh_cxl_almp_data[ 95:64]);
    almp_rx_repl_check_s[3] = |(rmlh_cxl_almp_data[31:0] ^ rmlh_cxl_almp_data[127:96]);
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL Received ALMP Message Decoder
// -------------------------------------------------------------------------------------
// If Receive Path is not enabled or ALMP replication error or RasDp failure in 256B mode is detected then discard received ALMP
assign rx_almp_data_s = {rmlh_cxl_almp_data[31:16], (rmlh_cxl_almp_dv & almp_rx_en & ( cxl_pcie_flit_mode? !rx_almp_rasdp_err_s : ~almp_rx_repl_error_s))};

always_comb begin
    if (rx_almp_data_s.valid & (rx_almp_data_s.vlsm_inst == CXL_IO)) begin
        almp_io_rx_request      = (rx_almp_data_s.almp_type == REQUEST);
        almp_io_rx_status       = (rx_almp_data_s.almp_type == STATUS);
        almp_io_rx_link_state   = rx_almp_data_s.almp_enc;
    end
    else begin
        almp_io_rx_request      = 1'b0;
        almp_io_rx_status       = 1'b0;
        almp_io_rx_link_state   = RESET;
    end
end

always_comb begin
    if (rx_almp_data_s.valid & (rx_almp_data_s.vlsm_inst == CXL_MEM_CACHE)) begin
        almp_mc_rx_request      = (rx_almp_data_s.almp_type == REQUEST);
        almp_mc_rx_status       = (rx_almp_data_s.almp_type == STATUS);
        almp_mc_rx_link_state   = rx_almp_data_s.almp_enc;
    end
    else begin
        almp_mc_rx_request      = 1'b0;
        almp_mc_rx_status       = 1'b0;
        almp_mc_rx_link_state   = RESET;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL TX/RX ALMP Datapath Enable
//
// After fresh boot first ALMP must be from Host to Device, therefore once SMLH link is
// up enable Host Transmitter only. To enable Device Transmitter wait for at least one
// ALMP to be received.
//
// -------------------------------------------------------------------------------------
assign almp_tx_en = cxl_link_up && almp_tx_en_r;

always_comb begin
    // After fresh boot first ALMP must be from Host to Device
    if (cxl_link_up) begin
        // For Host enable Transmit path when cxl_link_up is up
        if (!cxl_device_type)
            almp_tx_en_nxt = 1'b1;
        // For Device enable Transmit path once first ALMP is received
        else if (rmlh_cxl_almp_dv) 
            almp_tx_en_nxt = 1'b1;
        else
            almp_tx_en_nxt = almp_tx_en_r;
    end
    else begin
        almp_tx_en_nxt = almp_tx_en_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        almp_tx_en_r <= #TP 1'b0;
    end
    else begin
        almp_tx_en_r <= #TP almp_tx_en_nxt;
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// RASDP checker 256B received almp, only lower 32 bit of ALMP need to be checked (as replication is a 68B feature)
// -------------------------------------------------------------------------------------
assign rx_almp_buff_chk_in_dv_s = rx_almp_buff_dv_s && cxl_pcie_flit_mode;

DWC_cxl_almp_rx_rasdp
 u_DWC_cxl_almp_rx_rasdp (
    .core_clk                  ( core_clk                     ),
    .core_rst_n                ( core_rst_n                   ),
    .ras_dp_err_inj            ( ras_dp_err_inj               ),
    .rmlh_cxl_almp_dv_i        ( rx_almp_buff_chk_in_dv_s     ),
    .rmlh_cxl_almp_data_i      ( rx_almp_buff_data_s[47:16]   ),
    .rmlh_cxl_almp_data_chk_i  ( rx_almp_buff_data_chk_s[5:2] ),
    .rmlh_cxl_almp_dv_o        ( rx_almp_rasdp_dv_s           ),
    .rmlh_cxl_almp_data_o      ( rx_almp_rasdp_data_s         ),
    .rx_almp_rasdp_err         ( rx_almp_rasdp_err_s          ),
    .rx_almp_rasdp_err_log     ( rx_almp_rasdp_err_log        )
);
 assign rmlh_cxl_almp_dv     = cxl_pcie_flit_mode ? rx_almp_rasdp_dv_s            : rx_almp_buff_dv_s;
 assign rmlh_cxl_almp_data_s = cxl_pcie_flit_mode ? {96'h0, rx_almp_rasdp_data_s} : rx_almp_buff_data_s;

// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// ALMP Decoder Assertions
// -------------------------------------------------------------------------------------
//VCS coverage off
//VCS coverage on
// -------------------------------------------------------------------------------------

endmodule
