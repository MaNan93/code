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
// ---  RCS information:
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_flit_buff.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description: CXL Flit receive buffer that aligns RPLH
// --- sub-set of SPIF interface signals to the Link Layer datapath width
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
 
module rplh_flit_buff 
    import spif_pkg::stream_id_e;
    import spif_pkg::SID_RSVD;
    import spif_pkg::SPIF_NBYTES;
#(
    parameter TP                     = `TP,         // Clock to Q delay (simulator insurance)
    parameter stream_id_e  STREAM_ID = SID_RSVD,    // Link Layer Stream ID on SPIF Interface
    parameter FLUSH_ENABLE           = 1,           // Enable flushing buffer with pl_rx_flush
    parameter LL_NBYTES              = 64,          // Link Layer datapath width in bytes
    parameter FLIT_WIDTH             = 512,         // Indicates the flit width for the buffer
    parameter FLIT_OUT_REG           = 0            // Output register
) 
                         (
    // Interfaces
    spif_if.rplh_slave_mp                  b_rplh_spif,         // RPLH SPIF Interface
    // Inputs
    input                                  core_clk,            // Core Clock
    input                                  core_rst_n,          // Core Reset
    input                                  pcie_flit_mode,      // PCIe Flit Mode Enabled
    input                                  rplh_buff_enable,    // Enable RPLH flit buffer
    // Outputs
    output logic                           rx_flit_valid,       // Received flit valid
    output logic [LL_NBYTES*8-1:0]         rx_flit_data,        // Received flit data
    output logic [LL_NBYTES-1:0]           rx_flit_data_chk,    // Received flit data protection
    output logic                           rx_crc_valid,        // Received crc valid
    output logic [15:0]                    rx_crc_data          // Received crc data
);

logic                     rx_flit_valid_s;
logic [LL_NBYTES*8-1:0]   rx_flit_data_s;
logic [LL_NBYTES-1:0]     rx_flit_data_chk_s;
logic                     rplh_spif_valid_s;
logic                     rplh_spif_flush_s;

// If STREAM_ID is equal to SID_RSVD then disable Stream ID filter
assign rplh_spif_valid_s = rplh_buff_enable && b_rplh_spif.s_pl_valid && ((STREAM_ID == SID_RSVD) ? 1'b1 : (b_rplh_spif.s_pl_stream == STREAM_ID));
// Check whether flushing of the buffer with pl_rx_flush is allowed or not
assign rplh_spif_flush_s = FLUSH_ENABLE ? b_rplh_spif.s_pl_rx_flush : 1'b0;

// -------------------------------------------------------------------------------------
// Accumulates FLIT_RATIO number of LL_NBYTES bytes in 256B Flit Mode
// -------------------------------------------------------------------------------------
localparam FLIT_RATIO = FLIT_WIDTH/(SPIF_NBYTES*8);

logic ll_dw_busy_s;

generate
  if (FLIT_RATIO == 1) begin : gen_flit_ratio_disable

assign ll_dw_busy_s = 1'b0;

  end else begin : gen_flit_ratio_enable

localparam F68B_RATIO      = 64/SPIF_NBYTES;
localparam F68B_RATIO_LOG2 = $clog2(F68B_RATIO);
localparam FLIT_RATIO_LOG2 = $clog2(FLIT_RATIO);

logic [FLIT_RATIO_LOG2-1:0] ll_dw_cntr_r, ll_dw_cntr_nxt; // Received LL_DWs counter in the flit
logic                       ll_dw_done_s;

assign ll_dw_busy_s = |ll_dw_cntr_r;
assign ll_dw_done_s = !pcie_flit_mode ? 1'b1 : (&ll_dw_cntr_r);

always_comb begin
    if (rplh_spif_flush_s)
        ll_dw_cntr_nxt = '0;
    else if (rplh_spif_valid_s)
        ll_dw_cntr_nxt = ll_dw_done_s ? '0 : (ll_dw_cntr_r + 'd1);
    else
        ll_dw_cntr_nxt = ll_dw_cntr_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        ll_dw_cntr_r <= #TP '0;
    end
    else begin
        ll_dw_cntr_r <= #TP ll_dw_cntr_nxt;
    end
end

  end
endgenerate
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Flit Accumulation Logic - accumulates flit on the SPIF interface
// -------------------------------------------------------------------------------------
generate
  if (SPIF_NBYTES < LL_NBYTES) begin : gen_buff_less

localparam DW_RATIO_LOG2 = $clog2(LL_NBYTES/SPIF_NBYTES);

logic [DW_RATIO_LOG2-1:0]              rx_dw_cntr_r, rx_dw_cntr_nxt;   // Received DWs counter in the flit
logic [(LL_NBYTES-SPIF_NBYTES)*8-1:0]  rx_buff_r, rx_buff_nxt;         // Received flit buffer
logic [(LL_NBYTES-SPIF_NBYTES)-1:0]    rx_buff_chk_r, rx_buff_chk_nxt; // Received flit protection buffer

assign rx_flit_valid_s    = rplh_spif_valid_s && (&rx_dw_cntr_r);
assign rx_flit_data_s     = {b_rplh_spif.s_pl_data, rx_buff_r};
assign rx_flit_data_chk_s = {b_rplh_spif.s_pl_data_chk, rx_buff_chk_r};

always_comb begin
    if (rplh_spif_flush_s || rx_flit_valid_s) begin
        rx_dw_cntr_nxt  = '0;
        rx_buff_nxt     = '0;
        rx_buff_chk_nxt = '0;
    end
    else if (rplh_spif_valid_s) begin
        rx_dw_cntr_nxt  = rx_dw_cntr_r + 'd1;
        rx_buff_nxt     = rx_flit_data_s[(LL_NBYTES*8)-1:(SPIF_NBYTES*8)];
        rx_buff_chk_nxt = rx_flit_data_chk_s[LL_NBYTES-1:SPIF_NBYTES];
    end
    else begin
        rx_dw_cntr_nxt  = rx_dw_cntr_r;
        rx_buff_nxt     = rx_buff_r;
        rx_buff_chk_nxt = rx_buff_chk_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        rx_dw_cntr_r  <= #TP '0;
        rx_buff_r     <= #TP '0;
        rx_buff_chk_r <= #TP '0;
    end
    else begin
        rx_dw_cntr_r <= #TP rx_dw_cntr_nxt;
        rx_buff_r    <= #TP rx_buff_nxt;
        rx_buff_chk_r <= #TP rx_buff_chk_nxt;
    end
end

  end else begin : gen_buff_equal

assign rx_flit_valid_s    = rplh_spif_valid_s && !ll_dw_busy_s;
assign rx_flit_data_s     = b_rplh_spif.s_pl_data[LL_NBYTES*8-1:0];
assign rx_flit_data_chk_s = b_rplh_spif.s_pl_data_chk[LL_NBYTES-1:0];

  end
endgenerate
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Optional output register
// -------------------------------------------------------------------------------------
delay_n
 #(
    .N     (FLIT_OUT_REG),
    .WD    (1 + LL_NBYTES*8 + LL_NBYTES + 1 + 16)
) u_delay_buff_out_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({rx_flit_valid_s, rx_flit_data_s, rx_flit_data_chk_s, b_rplh_spif.s_pl_crc_valid, b_rplh_spif.s_pl_crc_data}),
    .dout  ({rx_flit_valid  , rx_flit_data  , rx_flit_data_chk  , rx_crc_valid              , rx_crc_data              })
);
// -------------------------------------------------------------------------------------

endmodule // rplh_flit_buff

