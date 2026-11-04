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
// ---  $DateTime: 2023/12/22 07:15:34 $
// ---  $Revision: #4 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/sdlh_spif.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Data Link Layer State Management (SDLH) - SPIF Interface
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"

module sdlh_spif 
  import spif_pkg::protocol_type_e;
  import spif_pkg::protocol_fmt_e;
  import spif_pkg::protocol_cfg_t;
  import spif_pkg::RESET;
  import spif_pkg::ACTIVE;
  import spif_pkg::DISABLED;
  import spif_pkg::LINKRESET;
  import spif_pkg::LINKERROR;
  import spif_pkg::IDLE_L1_1;
  import spif_pkg::L2;
#(
  parameter  TP            = `TP
) (
// Interfaces --------------------------------------------------------------------------
  spif_if.xplh_master_mp              b_xdlh_spif,            // XDLH SPIF interface
  spif_if.rplh_master_mp              b_rdlh_spif,            // RDLH SPIF interface
  spif_if.cfgi_master_mp              b_cfgi_spif,             // CFGI SPIF interface
  spif_if.slave_mp                    b_splh_spif,            // SPLH SPIF interface
// Inputs ------------------------------------------------------------------------------
  input                               core_clk,               // Core clock
  input                               core_rst_n,             // Core reset
  input                               cfg_rasdp_linkdown_en,  // Enable Link Down on RASDP uncorrectable error
  input  [1:0]                        rdlh_link_state,        // RDLH DLCMSM State
  input                               rdlh_retrain_req,       // RDLH Retrain Request
  input                               rtlh_retrain_req,       // RTLH Retrain Request
  input                               xdlh_retrain_req,       // XDLH Retrain Request
  input                               pm_cfg_retrain_req,     // Config Retrain Request (latched in PM Wakeup)
  input                               pm_app_init_rst,        // Application Link Reset Request (latched in PM Wakeup)
  input                               lp_pcie_clk_ack,        // PM Clock Acknowledge
  input                               lp_pcie_wake_req,       // PM Wakeup Request
  input                               pm_prot_req_l0s,        // PM Protocol FSM L0S Request
  input                               pm_prot_req_l1,         // PM Protocol FSM L1 Request
  input                               pm_prot_req_l2,         // PM Protocol FSM L2 Request
  input                               lp_linkmode_req,        // L0p Controller Link Mode Change Request
  input                               lp_linkmode_rmt,        // L0p Controller Link Mode Remote Request
  input  [5:0]                        lp_linkmode,            // L0p Controller Requested Link Mode
  input                               lp_l0p_flit_count_en,   // L0p Flit Counter Enable
  input                               xdlh_lp_stall_ack,      // XDLH Stall Acknowledge
  output                              xdlh_pl_stall_req,      // XDLH Stall Request
  output                              xdlh_pm_state_req,      // XDLH PM Entry Request (allows DLLP propagation when stall_req is asserted)
  output                              pl_linkmode_rdy,        // LogPHY is ready to accept new Link Mode Request
  output  [5:0]                       pl_linkmode_cfg,        // LogPHY negotiated Link Mode during Configuration phase
  output  [2:0]                       pl_l0p_flit_count,      // L0p Flit Counter
  output  protocol_cfg_t              pl_protocol_cfg         // Protocol Configuration for DLH Layer
);

logic int_retrain_req;

assign int_retrain_req = rdlh_retrain_req || rtlh_retrain_req || xdlh_retrain_req || pm_cfg_retrain_req;

assign xdlh_pl_stall_req = b_splh_spif.s_pl_stall_req;
assign xdlh_pm_state_req = (b_splh_spif.s_lp_state_req inside {IDLE_L1_1, L2});

// -------------------------------------------------------------------------------------
// XDLH SPIF Interface Connections
// -------------------------------------------------------------------------------------
assign b_xdlh_spif.s_pl_dllp_trdy     = b_splh_spif.s_pl_dllp_trdy     ;
assign b_xdlh_spif.s_pl_skip_trdy     = b_splh_spif.s_pl_skip_trdy     ;
assign b_xdlh_spif.s_pl_trdy          = b_splh_spif.s_pl_trdy          ;
assign b_splh_spif.s_lp_stream        = b_xdlh_spif.s_lp_stream        ;
assign b_splh_spif.s_lp_irdy          = b_xdlh_spif.s_lp_irdy          ;
assign b_splh_spif.s_lp_pri           = b_xdlh_spif.s_lp_pri           ;
assign b_splh_spif.s_lp_valid         = b_xdlh_spif.s_lp_valid         ;
assign b_splh_spif.s_lp_data          = b_xdlh_spif.s_lp_data          ;
assign b_splh_spif.s_lp_crc_valid     = b_xdlh_spif.s_lp_crc_valid     ;
assign b_splh_spif.s_lp_crc_data      = b_xdlh_spif.s_lp_crc_data      ;
assign b_splh_spif.s_lp_data_chk      = b_xdlh_spif.s_lp_data_chk      ;
assign b_splh_spif.s_lp_rasdp_error   = b_xdlh_spif.s_lp_rasdp_error   ;
assign b_splh_spif.s_lp_dlp_start     = b_xdlh_spif.s_lp_dlp_start     ;
assign b_splh_spif.s_lp_dlp_end       = b_xdlh_spif.s_lp_dlp_end       ;
assign b_splh_spif.s_lp_tlp_start     = b_xdlh_spif.s_lp_tlp_start     ;
assign b_splh_spif.s_lp_tlp_end       = b_xdlh_spif.s_lp_tlp_end       ;
assign b_splh_spif.s_lp_dllp_valid    = b_xdlh_spif.s_lp_dllp_valid    ;
assign b_splh_spif.s_lp_dllp_ofc      = b_xdlh_spif.s_lp_dllp_ofc      ;
assign b_splh_spif.s_lp_dllp_data     = b_xdlh_spif.s_lp_dllp_data     ;
assign b_splh_spif.s_lp_nop_flit      = b_xdlh_spif.s_lp_nop_flit      ;
assign b_splh_spif.s_lp_corrupt_crc   = b_xdlh_spif.s_lp_corrupt_crc   ;

// -------------------------------------------------------------------------------------
// RDLH SPIF Interface Connections
// -------------------------------------------------------------------------------------
assign b_rdlh_spif.s_pl_stream        = b_splh_spif.s_pl_stream        ;
assign b_rdlh_spif.s_pl_valid         = b_splh_spif.s_pl_valid         ;
assign b_rdlh_spif.s_pl_data          = b_splh_spif.s_pl_data          ;
assign b_rdlh_spif.s_pl_data_chk      = b_splh_spif.s_pl_data_chk      ;
assign b_rdlh_spif.s_pl_crc_valid     = b_splh_spif.s_pl_crc_valid     ;
assign b_rdlh_spif.s_pl_crc_data      = b_splh_spif.s_pl_crc_data      ;
assign b_rdlh_spif.s_pl_rx_flush      = b_splh_spif.s_pl_rx_flush      ;
assign b_rdlh_spif.s_pl_rx_nak        = b_splh_spif.s_pl_rx_nak        ;
assign b_rdlh_spif.s_pl_dlp_start     = b_splh_spif.s_pl_dlp_start     ;
assign b_rdlh_spif.s_pl_dlp_end       = b_splh_spif.s_pl_dlp_end       ;
assign b_rdlh_spif.s_pl_tlp_start     = b_splh_spif.s_pl_tlp_start     ;
assign b_rdlh_spif.s_pl_tlp_end       = b_splh_spif.s_pl_tlp_end       ;
assign b_rdlh_spif.s_pl_tlp_edb       = b_splh_spif.s_pl_tlp_edb       ;
assign b_rdlh_spif.s_pl_error         = b_splh_spif.s_pl_error         ;
assign b_rdlh_spif.s_pl_nullified     = b_splh_spif.s_pl_nullified     ;
assign b_rdlh_spif.s_pl_poisoned      = b_splh_spif.s_pl_poisoned      ;
assign b_rdlh_spif.s_pl_dllp_valid    = b_splh_spif.s_pl_dllp_valid    ;
assign b_rdlh_spif.s_pl_dllp_ofc      = b_splh_spif.s_pl_dllp_ofc      ;
assign b_rdlh_spif.s_pl_dllp_data     = b_splh_spif.s_pl_dllp_data     ;

// -------------------------------------------------------------------------------------
// CFGI SPIF Interface Connections
// -------------------------------------------------------------------------------------
assign b_splh_spif.s_lp_cfg_vld       = b_cfgi_spif.s_lp_cfg_vld       ;
assign b_splh_spif.s_lp_cfg_data      = b_cfgi_spif.s_lp_cfg_data      ;
assign b_cfgi_spif.s_pl_cfg_vld       = b_splh_spif.s_pl_cfg_vld       ;
assign b_cfgi_spif.s_pl_cfg_data      = b_splh_spif.s_pl_cfg_data      ;

// -------------------------------------------------------------------------------------
// SPIF Interface
// -------------------------------------------------------------------------------------
logic                         lp_protocol_vld;        // Link Layer Protocol Valid
protocol_type_e               lp_protocol;            // Link Layer Protocol Type
protocol_fmt_e                lp_protocol_fmt;        // Link Layer Protocol Flit Format
logic                         lp_rx_active_sts_r;
logic                         lp_stall_ack;
logic                         pm_state_req;

// If L1.2 power gating is enabled then retain the value of xdlh_lp_stall_ack during L1 states, 
// must be always 1 as a transition to L1 state requires Stall Req/Ack handshake
assign lp_stall_ack = xdlh_lp_stall_ack;


always_ff @(posedge core_clk or negedge core_rst_n) begin 
    if (!core_rst_n) begin
       lp_rx_active_sts_r <= # TP 1'b0;
    end else begin
       lp_rx_active_sts_r <= # TP b_splh_spif.s_pl_rx_active_req;
    end
end

assign b_splh_spif.s_lp_stall_ack     = lp_stall_ack;
assign b_splh_spif.s_lp_rx_active_sts = lp_rx_active_sts_r;
assign b_splh_spif.s_lp_dl_active     = pl_protocol_cfg.spif_enable ? (rdlh_link_state == `S_DL_ACTIVE) : 1'b0;
assign b_splh_spif.s_lp_clk_ack       = lp_pcie_clk_ack;
assign b_splh_spif.s_lp_wake_req      = lp_pcie_wake_req;
assign b_splh_spif.s_lp_linkerror     = 1'b0 || (cfg_rasdp_linkdown_en && b_xdlh_spif.s_lp_rasdp_error);

// -------------------------------------------------------------------------------------
// L0p Interface
// -------------------------------------------------------------------------------------
logic              lp_linkmode_rmt_nxt;        // L0p Request is directed by the remote partner - next state
logic              lp_linkmode_rmt_r;          // L0p Request is directed by the remote partner - register
logic [5:0]        lp_linkmode_nxt;            // Link Layer requested link mode - next state
logic [5:0]        lp_linkmode_r;              // Link Layer requested link mode - register
logic              pl_linkmode_rdy_nxt;        // LogPHY is ready to accept new L0p request - next state
logic              pl_linkmode_rdy_r;          // LogPHY is ready to accept new L0p request - register
logic              pl_link_up_r;               // Latch pl_link_up on rising edge
logic [5:0]        pl_linkmode_cfg_r;          // LogPHY negotiated Link Mode during Configuration phase

// Interface assignments
assign b_splh_spif.s_lp_linkmode_pri  = '0;    // Not used on the interface to LogPHY
assign b_splh_spif.s_lp_linkmode_rmt  = lp_linkmode_rmt_r;
assign b_splh_spif.s_lp_linkmode      = lp_linkmode_r;

// Output assignments
assign pl_linkmode_rdy = pl_linkmode_rdy_r;
assign pl_linkmode_cfg = pl_linkmode_cfg_r;

always_comb begin
    // If LogPHY is in retrain (EIOS is received) then de-assert Link Mode change ready flag and 
    // restore requested Link Mode to LogPHY Link Mode
    if (b_splh_spif.s_pl_phyinretrain) begin
        pl_linkmode_rdy_nxt = 1'b0;
        lp_linkmode_rmt_nxt = 1'b0;
        lp_linkmode_nxt     = b_splh_spif.s_pl_linkmode;
    // If Link Layer requests Link Mode change then de-assert Link Mode change ready flag and
    // change the requested Link Mode to the LogPHY on SPIF interface
    end else if (lp_linkmode_req && pl_linkmode_rdy_r && (b_splh_spif.s_pl_state_sts == ACTIVE)) begin
        pl_linkmode_rdy_nxt = 1'b0;
        lp_linkmode_rmt_nxt = lp_linkmode_rmt;
        lp_linkmode_nxt     = {1'b0, lp_linkmode};
    // If LogPHY changes to the Link Mode requested by the Link Layer, i.e. Link Mode change request is 
    // complete, then assert Link Mode change ready flag to accept new Link Mode change request
    end else if (b_splh_spif.s_pl_linkmode == lp_linkmode_r) begin
        pl_linkmode_rdy_nxt = 1'b1;
        lp_linkmode_rmt_nxt = 1'b0;
        lp_linkmode_nxt     = b_splh_spif.s_pl_linkmode;
    // Preserve requested Link Mode and Link Mode change ready flag if none of the conditions above is met
    end else begin
        pl_linkmode_rdy_nxt = pl_linkmode_rdy_r;
        lp_linkmode_rmt_nxt = lp_linkmode_rmt_r;
        lp_linkmode_nxt     = lp_linkmode_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        pl_linkmode_rdy_r <= #TP '0;
        lp_linkmode_rmt_r <= #TP '0;
        lp_linkmode_r     <= #TP '0;
    end else begin
        pl_linkmode_rdy_r <= #TP pl_linkmode_rdy_nxt;
        lp_linkmode_rmt_r <= #TP lp_linkmode_rmt_nxt;
        lp_linkmode_r     <= #TP lp_linkmode_nxt;
    end  
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        pl_link_up_r      <= #TP '0;
        pl_linkmode_cfg_r <= #TP '0;
    // Latch LogPHY negotiated Link Mode during Configuration phase
    end else if (b_splh_spif.s_pl_link_up && !pl_link_up_r) begin
        pl_link_up_r      <= #TP b_splh_spif.s_pl_link_up;
        pl_linkmode_cfg_r <= #TP b_splh_spif.s_pl_linkmode;
    end  
end

// -------------------------------------------------------------------------------------
// L0P Flit Counter: counts time windows during which LogPHY transmits a flit
// -------------------------------------------------------------------------------------
localparam DW_RATIO_LOG2 = $clog2(`CX_FLIT_CORE_WIDTH_RATIO);
localparam FLIT_CNT_SIZE = 3 + DW_RATIO_LOG2;

logic [FLIT_CNT_SIZE-1:0] l0p_flit_count_r; // Counts up to 4 flits

assign pl_l0p_flit_count = l0p_flit_count_r[FLIT_CNT_SIZE-1:DW_RATIO_LOG2];

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        l0p_flit_count_r <= #TP '0;
    end else if (lp_l0p_flit_count_en && b_splh_spif.s_pl_trdy && !l0p_flit_count_r[FLIT_CNT_SIZE-1]) begin
        l0p_flit_count_r <= #TP l0p_flit_count_r + 'd1;
    end else if (!lp_l0p_flit_count_en) begin
        l0p_flit_count_r <= #TP '0;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Protocol Decoder Instantiation to be used on the hierarchy level
// -------------------------------------------------------------------------------------
spif_protocol_dec
 u_spif_protocol (
    // Inputs
    .core_clk        ( core_clk                      ),
    .core_rst_n      ( core_rst_n                    ),
    .pl_protocol_vld ( lp_protocol_vld               ),
    .pl_protocol     ( lp_protocol                   ),
    .pl_protocol_fmt ( lp_protocol_fmt               ),
    // Outputs
    .pl_protocol_cfg ( pl_protocol_cfg               )
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// SPIF Link Layer State Request FSM Instantiation
// -------------------------------------------------------------------------------------
spif_state_req
 #(
    .PROTOCOL        ( 1'b0                          )
) u_lp_state_req (
    // Inputs
    .core_clk        ( core_clk                      ),
    .core_rst_n      ( core_rst_n                    ),
    .pl_protocol_vld ( b_splh_spif.s_pl_protocol_vld ),
    .pl_protocol     ( b_splh_spif.s_pl_protocol     ),
    .pl_protocol_fmt ( b_splh_spif.s_pl_protocol_fmt ),
    .pl_inband_pres  ( b_splh_spif.s_pl_inband_pres  ),
    .pl_phyinretrain ( b_splh_spif.s_pl_phyinretrain ),
    .pl_state_sts    ( b_splh_spif.s_pl_state_sts    ),
    .pl_stall_req    ( b_splh_spif.s_pl_stall_req    ),
    .lp_pm_l0s_req   ( pm_prot_req_l0s               ),
    .lp_pm_l1_req    ( pm_prot_req_l1                ),
    .lp_pm_l2_req    ( pm_prot_req_l2                ),
    .lp_retrain_req  ( int_retrain_req               ),
    .lp_reset_req    ( pm_app_init_rst               ),
    .lp_disable_req  ( 1'b0                          ),
    // Outputs
    .lp_state_req    ( b_splh_spif.s_lp_state_req    ),
    .lp_protocol_vld ( lp_protocol_vld               ),
    .lp_protocol     ( lp_protocol                   ),
    .lp_protocol_fmt ( lp_protocol_fmt               )
);
// -------------------------------------------------------------------------------------

endmodule
