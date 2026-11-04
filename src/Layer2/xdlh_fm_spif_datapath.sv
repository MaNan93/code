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
// ---    $DateTime: 2024/02/09 08:06:12 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_fm_spif_datapath.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description: XPLH Flit Mode SPIF Datapath
// --- For Multi-Stream Architecture prefetches flit from XDLH
// --- Generates Link Layer NOP flits
// --- Inserts 2-byte Flit Header at SOF cycle on CXL.io in CXL 256B Flit Mode
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"

module xdlh_fm_spif_datapath
    import spif_pkg::SPIF_NBYTES;
    import spif_pkg::SPIF_NDLLP;
#(
    parameter   TP        = `TP,                                  // Clock to Q delay (simulator insurance)
    parameter   DW        = SPIF_NBYTES*8,                        // Width of datapath in bits.
    parameter   DW_W_PROT = DW + SPIF_NBYTES // Width of datapath with protection code in bits.
) (
// Inputs ------------------------------------------------------------------------------
    input                             core_clk,                   // Core Clock
    input                             core_rst_n,                 // Core Reset
    input                             xdlh_flit_in_progress,      // XTLH to XDLH Interface - Flit in progress in the Flit Marker module
    input                             xdlh_xplh_spif_enable,      // Enable SPIF Interface on XDLH to XPLH interface
    input                             xtlh_xdlh_cmd_done,         // XTLH to XDLH cmd handshake done
    input                             xdlh_xplh_stall_req,        // XDLH to XPLH IF - Stall Request
    input                             xdlh_pm_state_req,          // Link Layer requests PM entry
    input                             xdlh_xplh_sof,              // XDLH to XPLH Interface - Start of Flit marker
    input          [1:0]              xdlh_xplh_eof,              // XDLH to XPLH Interface - End of Flit marker
    input                             xdlh_xplh_dv,               // XDLH to XPLH Interface - Data Valid
    input          [DW_W_PROT-1:0]    xdlh_xplh_data_in,          // XDLH to XPLH Interface - CXL.io flit for transmission.
    input                             xdlh_xplh_dllp_pending,     // XDLH to XPLH Interface - DLLP Pending
    input                             xdlh_xplh_dllp_valid,       // XDLH to XPLH Interface - DLLP Valid
    input                             xdlh_xplh_dllp_ofc,         // XDLH to XPLH Interface - DLLP Optimized_Update_FC
    input          [SPIF_NDLLP*8-1:0] xdlh_xplh_dllp_data,        // XDLH to XPLH Interface - DLLP Payload
    input                             xplh_xdlh_dllp_halt,        // XDLH to XPLH Interface - DLLP Halt
    input                             xplh_arbmux_xdlh_halt,      // XPLH ARB/MUX to XDLH IF - Halt
// Outputs -----------------------------------------------------------------------------
    output  logic                     xdlh_xplh_stall_ack,        // XDLH to XPLH IF - Stall Acknowledge
    output  logic                     xdlh_xplh_dllp_valid_out,   // XDLH to XPLH Interface - DLLP Valid
    output  logic                     xdlh_xplh_dllp_ofc_out,     // XDLH to XPLH Interface - DLLP Optimized_Update_FC
    output  logic  [SPIF_NDLLP*8-1:0] xdlh_xplh_dllp_data_out,    // XDLH to XPLH Interface - DLLP Payload
    output  logic                     xplh_xdlh_dllp_halt_out,    // XDLH to XPLH Interface - DLLP Halt
    output  logic                     xdlh_xplh_halt_out,         // XDLH to XPLH ARB/MUX Interface - Halt
    output  logic                     xdlh_xplh_dv_out,           // XDLH to XPLH ARB/MUX Interface - Data Valid
    output  logic                     xdlh_xplh_sof_out,          // XDLH to XPLH ARB/MUX Interface - Start of Flit
    output  logic  [1:0]              xdlh_xplh_eof_out,          // XDLH to XPLH ARB/MUX Interface - End of Flit
    output  logic                     xdlh_xplh_enf_out,          // XDLH to XPLH ARB/MUX Interface - End of NOP flit
    output  logic  [DW_W_PROT-1:0]    xdlh_xplh_data_out          // XDLH to XPLH ARB/MUX Interface - CXL.io flit for transmission after Flit Header insertion
);

// Local parameters
localparam       FLIT_DW_RATIO = 2048 / (SPIF_NBYTES*8);  // Number of cycles required to complete 256B flit on the interface to ARB/MUX
localparam logic PARITY_MODE   = `CX_RAS_PARITY_MODE;     // Even Parity - 0 (CX_RASDP=2), Odd Parity - 1 (CX_RASDP=1)

// Internal declarations
logic                     int_xdlh_nop_enable;      // Enable NOP Generation
// XDLH CXL.io NOP Interface signals
logic                     xdlh_nop_dv_cnt_done;     // XDLH NOP Interface - flit valid cycle counter done
logic [FLIT_DW_RATIO-1:0] xdlh_nop_dv_cnt_nxt;      // XDLH NOP Interface - flit valid cycle counter - next state
logic [FLIT_DW_RATIO-1:0] xdlh_nop_dv_cnt_r;        // XDLH NOP Interface - flit valid cycle counter
logic                     xdlh_nop_dv;              // XDLH NOP Interface - Data Valid
logic                     xdlh_nop_sof;             // XDLH NOP Interface - SOF cycle
logic                     xdlh_nop_eof;             // XDLH NOP Interface - EOF Cycle
logic                     xdlh_pyld_sel_s;
logic                     xdlh_pyld_done_s;
logic                     xdlh_xplh_stall_ack_nxt;
logic                     xtlh_xdlh_cmd_done_nxt, xtlh_xdlh_cmd_done_r;

// -------------------------------------------------------------------------------------
// XDLH to XPLH DLLP Interface
// -------------------------------------------------------------------------------------
always_comb begin
    if (xdlh_xplh_spif_enable) begin
        xdlh_xplh_dllp_valid_out = xdlh_xplh_stall_ack ? '0 : xdlh_xplh_dllp_valid ;
        xdlh_xplh_dllp_ofc_out   = xdlh_xplh_stall_ack ? '0 : xdlh_xplh_dllp_ofc   ;
        xdlh_xplh_dllp_data_out  = xdlh_xplh_stall_ack ? '0 : xdlh_xplh_dllp_data  ;
        xplh_xdlh_dllp_halt_out  = xdlh_xplh_stall_ack ? '1 : xplh_xdlh_dllp_halt  ;
    end
    else begin
        xdlh_xplh_dllp_valid_out = xdlh_xplh_dllp_valid;
        xdlh_xplh_dllp_ofc_out   = xdlh_xplh_dllp_ofc;
        xdlh_xplh_dllp_data_out  = xdlh_xplh_dllp_data;
        xplh_xdlh_dllp_halt_out  = xplh_xdlh_dllp_halt;
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// XDLH to XPLH Interface output mux
// -------------------------------------------------------------------------------------
assign xdlh_pyld_sel_s = xdlh_xplh_sof ? (xdlh_nop_dv ? xdlh_nop_sof : 1'b1) : xdlh_xplh_dv;

always_comb begin
    if (xdlh_xplh_spif_enable) begin
        xdlh_xplh_dv_out   = xdlh_pyld_sel_s ? xdlh_xplh_dv          : xdlh_nop_dv;
        xdlh_xplh_data_out = xdlh_pyld_sel_s ? xdlh_xplh_data_in     : { {SPIF_NBYTES{PARITY_MODE}}, {DW{1'b0}}};
        xdlh_xplh_sof_out  = xdlh_pyld_sel_s ? xdlh_xplh_sof         : xdlh_nop_sof;
        xdlh_xplh_eof_out  = xdlh_pyld_sel_s ? xdlh_xplh_eof         : {2{xdlh_nop_eof}};
        xdlh_xplh_enf_out  = xdlh_pyld_sel_s ? 1'b0                  : xdlh_nop_dv;
        xdlh_xplh_halt_out = xdlh_pyld_sel_s ? xplh_arbmux_xdlh_halt : (xdlh_xplh_stall_req ? 1'b1 : xdlh_xplh_dv);
    end
    else begin
        xdlh_xplh_dv_out   = xdlh_xplh_dv;
        xdlh_xplh_data_out = xdlh_xplh_data_in;
        xdlh_xplh_sof_out  = xdlh_xplh_sof;
        xdlh_xplh_eof_out  = xdlh_xplh_eof;
        xdlh_xplh_enf_out  = 1'b0;
        xdlh_xplh_halt_out = xplh_arbmux_xdlh_halt;
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// NOP flit generator
// -------------------------------------------------------------------------------------
assign xdlh_nop_dv  = xdlh_nop_dv_cnt_r[0];
assign xdlh_nop_sof = xdlh_nop_dv_cnt_r[FLIT_DW_RATIO-1];
assign xdlh_nop_eof = (xdlh_nop_dv_cnt_r[1:0] == 2'b01);

// Enable NOP flit when there is no valid data on XDLH interface and there are pending DLLPs
assign int_xdlh_nop_enable  = xdlh_xplh_spif_enable && ((xdlh_xplh_dllp_pending || xdlh_xplh_dllp_valid) && !xdlh_xplh_dv) && !xdlh_xplh_stall_ack_nxt;
// Set NOP DV counter done if either NOP flit is not scheduled yet or on transmitting EOF cycle when NOP flit generation is enabled
assign xdlh_nop_dv_cnt_done = xdlh_nop_dv ? (!xdlh_pyld_sel_s && xdlh_nop_eof && !xplh_arbmux_xdlh_halt) : 1'b1;

always_comb begin
    if (int_xdlh_nop_enable && xdlh_nop_dv_cnt_done) begin
        xdlh_nop_dv_cnt_nxt = {FLIT_DW_RATIO{1'b1}};
    end
    else if (!xdlh_pyld_sel_s && xdlh_nop_dv && !xplh_arbmux_xdlh_halt) begin
        xdlh_nop_dv_cnt_nxt = xdlh_nop_dv_cnt_r >> 1;
    end
    else begin
        xdlh_nop_dv_cnt_nxt = xdlh_nop_dv_cnt_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        xdlh_nop_dv_cnt_r <= #TP '0;
    end
    else begin
        xdlh_nop_dv_cnt_r <= #TP xdlh_nop_dv_cnt_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// for CXL xdlh_xplh_dv is going through a buffer, it will de-assert after xtlh_xdlh_cmd_done de-asserts, so need to latch it
// -------------------------------------------------------------------------------------
always_comb begin
    if (xtlh_xdlh_cmd_done && xdlh_xplh_stall_req)
        xtlh_xdlh_cmd_done_nxt = 1'b1;
    else if (xdlh_xplh_stall_ack)
        xtlh_xdlh_cmd_done_nxt = 1'b0;
    else begin
        xtlh_xdlh_cmd_done_nxt = xtlh_xdlh_cmd_done_r;
    end
end

// -------------------------------------------------------------------------------------
// Stall Request/Acvknowledge Interface
// -------------------------------------------------------------------------------------
assign xdlh_pyld_done_s =  !xdlh_xplh_dv && xtlh_xdlh_cmd_done_r && !xdlh_flit_in_progress ;

always_comb begin
    if (xdlh_xplh_stall_req && xdlh_nop_dv_cnt_done && xdlh_pyld_done_s && (xdlh_pm_state_req ? !xdlh_xplh_dllp_valid : 1'b1))
        xdlh_xplh_stall_ack_nxt = 1'b1;
    else if (!xdlh_xplh_stall_req)
        xdlh_xplh_stall_ack_nxt = 1'b0;
    else begin
        xdlh_xplh_stall_ack_nxt = xdlh_xplh_stall_ack;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        xdlh_xplh_stall_ack  <= # TP '0;
        xtlh_xdlh_cmd_done_r <= # TP '0;
    end
    else begin
        xdlh_xplh_stall_ack  <= # TP xdlh_xplh_stall_ack_nxt;
        xtlh_xdlh_cmd_done_r <= # TP xtlh_xdlh_cmd_done_nxt;
    end
end
// -------------------------------------------------------------------------------------

`ifndef SYNTHESIS
//VCS coverage off

// Note: assertion to be moved into spif tracker
property p_check_no_dv_when_stall_ack;
  @(posedge core_clk) disable iff (core_rst_n !== 1'b1) (xdlh_xplh_stall_req && xdlh_xplh_stall_ack) |-> (!(xdlh_xplh_dv || xdlh_nop_dv));
endproperty

fv_chk_no_dv_when_stall_ack : assert property (p_check_no_dv_when_stall_ack) else $display("%t %m: ERROR: xdlh_xplh_dv when xdlh_xplh_stall_req && xdlh_xplh_stall_ack", $time);

//VCS coverage on
`endif // SYNTHESIS

endmodule // xdlh_fm_spif_datapath

