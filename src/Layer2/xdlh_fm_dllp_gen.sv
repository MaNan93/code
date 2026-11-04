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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #6 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_fm_dllp_gen.sv#6 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XDLH Flit Mode DLLP Generation
//
// Description: This module implements the arbitration and scheduling of DLLP's
//              when the controller is operating in Flit Mode.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xdlh_fm_dllp_gen
  import cx_pl_pkg::fm_dllp_struct;
  import cx_pl_pkg::dllp_struct;
  import cx_pl_pkg::dllp_type_e;
  import cx_pl_pkg::NOP_DLLP;
  import cx_pl_pkg::L0P_Request;
  import cx_pl_pkg::l0p_cmd_e;
  import cx_pl_pkg::l0p_ack_struct;
  import cx_pl_pkg::P_NVC;
  import cx_pl_pkg::dlp_is_vcx_init_fc;
  import cx_pl_pkg::dlp_is_update_fc;
  import cx_pl_pkg::LINK_MANAGEMENT;
  import cx_pl_pkg::PM_ENTER_L1;
  import cx_pl_pkg::PM_ENTER_L23;
  import cx_pl_pkg::PM_ACTIVE_STATE_REQUEST_L1;
  import cx_pl_pkg::PM_REQUEST_ACK;
  import cx_pl_pkg::DUMMY;
#(
  parameter P_NCLIENTS = 5,
  parameter TP  = `TP
)(
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                         core_clk,                   // Core Clock
  input                         core_rst_n,                 // Active low asynchronous reset
  // -------------------------------------------------------------------------------------
  // FC DLLP Interface
  // -------------------------------------------------------------------------------------
  input   [P_NVC-1:0]           rtlh_fc_init_status,        // Report VC as ready for traffic
  input   dllp_struct           rtlh_xdlh_dllp,             // Layer3 DLLP request 
  input                         rtlh_xdlh_opt_upd,          // DLLP is an Optimized Update FC DLLP
  output  logic                 xdlh_dllp_rtlh_ack,         // XDLH Acknowledges the FC DLLP has been sent
  output  logic [P_NVC-1:0]     xdlh_fm_dllp_fc_init_done,  // XDLH indicates that FC init is done
  output  logic                 xdlh_upd_fc_sent,           // Update FC sent FM
  // -------------------------------------------------------------------------------------
  // Power Management Interface
  // -------------------------------------------------------------------------------------
  output  logic                 xdlh_dllp_pending,          // Indicates no DLLP is pending to transmit
  input   dllp_struct           pm_xdlh_dllp,               // Power Management request to send PM DLLP
  output  logic                 xdlh_dllp_pm_ack,           // XDLH Acknowledges the PM DLLP has been sent
  // -------------------------------------------------------------------------------------
  // L0P DLLP Interface
  // -------------------------------------------------------------------------------------
  input   dllp_struct           xdlh_l0p_dllp,              // L0P DLLP
  output  l0p_ack_struct        xdlh_dllp_l0p_ack,          // Acknowledge the L0P DLLP has been Transmitted
  // -------------------------------------------------------------------------------------
  // Vendor Specific DLLP Interface
  // -------------------------------------------------------------------------------------
  input   dllp_struct           cdm_xdlh_dllp,              // Vendor Specific DLLP Request
  output  logic                 xdlh_dllp_cdm_ack,          // Acknowledge the Vendor Specific DLLP has been Transmitted
  // -------------------------------------------------------------------------------------
  // DL Feature DLLP Interface
  // -------------------------------------------------------------------------------------
  input   dllp_struct           dl_feature_dllp,            // DL Feature DLLP
  output  logic                 xdlh_dllp_feature_ack,      // DL Feature DLLP sent
  // -------------------------------------------------------------------------------------
  // XPLH Interface
  // -------------------------------------------------------------------------------------
  output  logic                 xdlh_fm_dllp_valid,         // DLLP Data Valid to PLH
  output  logic                 xplh_l0p_dllps_count,   
  input                         enter_low_power,            // Enter low power state 
  input                         smlh_in_rcvry,              // Entering recovery
  output  fm_dllp_struct        xdlh_fm_dllp_out,           // DLLP Data to Plh
  input                         xplh_xdlh_dllp_halt         // Back-Pressure from Plh
);

// -------------------------------------------------------------------------------------
// Declarations 
// -------------------------------------------------------------------------------------
localparam P_INDEX_WIDTH      = $clog2(P_NCLIENTS);
localparam P_REAL_INDEX_WIDTH = $clog2(P_NCLIENTS + 1);
localparam P_FIFO_DP          = 2;
localparam P_FIFO_ADD_WD      = $clog2(P_FIFO_DP);
localparam P_FIFO_WD          = $bits(fm_dllp_struct);


typedef enum logic [P_NCLIENTS - 1 : 0] {
  P_FEATURE_GRANT = {{(P_NCLIENTS - 1){1'b0}}, 1'b1},
  P_FC_GRANT      = {{(P_NCLIENTS - 2){1'b0}}, 1'b1, 1'b0},
  P_PM_GRANT      = {{(P_NCLIENTS - 3){1'b0}}, 1'b1, 2'b00},
  P_L0P_GRANT     = {{(P_NCLIENTS - 4){1'b0}}, 1'b1, 3'b000},
  P_VENDOR_GRANT  = {{(P_NCLIENTS - 5){1'b0}}, 1'b1, 4'b0000}
} dllp_grant_e;

localparam P_0 = 3'b000; // Highest Priority
localparam P_1 = 3'b001;
localparam P_2 = 3'b010;
localparam P_3 = 3'b011;
localparam P_4 = 3'b100; // Lowest Priority

logic [(P_NCLIENTS * 3) -1 : 0]   s_dllp_prior;
logic [1 : 0]                     r_prior_cnt;
logic [(P_NCLIENTS - 1) : 0]      s_dllp_req;
logic                             s_dllp_ack_or;
dllp_grant_e                      s_dllp_grant;
logic [(P_NCLIENTS - 1) : 0]      s_arb_grant;
logic [P_NVC - 1 : 0]             s_fc_init_done;
logic [1:0]                       r_fc_init_cnt;
logic [P_NVC - 1 : 0]             s_fc_init_push;
logic [P_NVC - 1 : 0]             s_fc_init_pop;
logic                             s_arb_enable;
logic                             r_arb_enable;
fm_dllp_struct                    s_fm_dllp;
fm_dllp_struct                    s_fifo_dllp;
fm_dllp_struct                    s_filt_dllp;
logic                             s_filt_dllp_valid;
logic                             s_en_filt;
logic                             s_pm_dllp;
logic                             s_l0p_dllp;
logic                             s_pm_dllp_out;
logic                             s_l0p_dllp_out;
l0p_cmd_e                         s_l0p_cmd;
l0p_cmd_e                         r_l0p_cmd;
logic                             s_grant_non_dl_fc;
logic                             s_dllp_fifo_full;
logic                             s_dllp_fifo_empty;
logic                             s_dllp_fifo_push_n;
logic                             s_dllp_fifo_pop_n;
logic [P_FIFO_ADD_WD : 0]         r_dllp_filt_cnt;
logic                             r_enter_low_power;
logic                             r_smlh_in_rcvry;
logic                             s_low_power_exit_fe;
logic                             s_rcvry_fe;
// Indication that L0P DLLP is sent by XPLH
assign xplh_l0p_dllps_count= !xplh_xdlh_dllp_halt && (xdlh_fm_dllp_out.dllp_type==LINK_MANAGEMENT);

// Arbitration Priority (highest to lowest)
// 0  DL FEATURE DLLP
// 1  L0P DLLP
// 2  FC DLLP
// 3  PM DLLP
// 4  Vendor Specific DLLP
// Mask all DLLP's apart from DL Feature and FC DLLP until FC Init is complete
assign s_grant_non_dl_fc = &xdlh_fm_dllp_fc_init_done;

assign s_dllp_req = {cdm_xdlh_dllp.valid, xdlh_l0p_dllp.valid, pm_xdlh_dllp.valid, rtlh_xdlh_dllp.valid, dl_feature_dllp.valid} & {{3{s_grant_non_dl_fc}}, 2'b11};

assign s_dllp_ack_or = xdlh_dllp_feature_ack || xdlh_dllp_rtlh_ack || xdlh_dllp_pm_ack || xdlh_dllp_l0p_ack.ack || xdlh_dllp_cdm_ack;

assign s_arb_enable = (|s_dllp_req) && !s_dllp_fifo_full && !s_dllp_ack_or;

always_ff @(posedge core_clk or negedge core_rst_n) begin : dllp_req_PROC
  if(!core_rst_n) begin
    r_arb_enable  <= #TP '0;
  end else begin
    r_arb_enable  <= #TP s_arb_enable;
  end
end : dllp_req_PROC

// Instantiate Arbiter
DWC_pcie_ctl_bcmmod52
 #(
  .N                (P_NCLIENTS),
  .PARK_MODE        (0),
  .PARK_INDEX       (0),
  .OUTPUT_MODE      (1),
  .INDEX_WIDTH      (P_INDEX_WIDTH),
  .REAL_INDEX_WIDTH (P_REAL_INDEX_WIDTH),
  .REG_DELAY_TIME   (1),
  .REG_DELAY_DENOM  (10)
) u_dllp_arb (
  // Inputs
  .clk          (core_clk),
  .rst_n        (core_rst_n),
  .init_n       (1'b1),
  .enable       (s_arb_enable),
  .request      (s_dllp_req),
  .prior        (s_dllp_prior),
  .lock         (5'b0),
  .mask         (5'b0),
  // Outputs
  .parked       (),
  .granted      (),
  .locked       (),
  .grant        (s_arb_grant),
  .grant_index  ()
);

// Counter increments on granted DLLP's when High Priority FC is not asserted
always_ff @(posedge core_clk or negedge core_rst_n) begin : dllp_cnt_PROC
  if(!core_rst_n) begin
    r_prior_cnt     <= #TP '0;
  end else begin
    if(r_arb_enable) begin
      // No DLLP reset to default priority
      if(s_dllp_req == '0)
        r_prior_cnt   <= #TP '0;
      else
        r_prior_cnt   <= #TP (r_prior_cnt == 2) ? '0 : r_prior_cnt + 1;
    end
  end
end : dllp_cnt_PROC

// DL FEATURE is always highest
always_comb begin : dllp_prior_PROC
  unique case(r_prior_cnt)
    1 : s_dllp_prior = {P_3, P_1, P_2, P_4, P_0};
    2 : s_dllp_prior = {P_2, P_1, P_4, P_3, P_0};
    default : s_dllp_prior = {P_4, P_1, P_3, P_2, P_0};
  endcase
end : dllp_prior_PROC

assign s_dllp_grant = dllp_grant_e'(s_arb_grant);

// Select the DLLP to send 
always_comb begin : dllp_PROC
  s_fm_dllp = '0;
  s_fm_dllp.dllp_type = NOP_DLLP;
  xdlh_dllp_feature_ack = 1'b0;
  xdlh_dllp_rtlh_ack = 1'b0;
  xdlh_dllp_pm_ack = 1'b0;
  xdlh_dllp_l0p_ack.ack = '0;
  xdlh_dllp_l0p_ack.l0p_cmd = l0p_cmd_e'(0);
  xdlh_dllp_cdm_ack = 1'b0;
  // Arbiter locked to a request
  unique case(s_dllp_grant)
    P_FEATURE_GRANT : begin
      s_fm_dllp.pyld = dl_feature_dllp.pyld;
      s_fm_dllp.dllp_type = dl_feature_dllp.dllp_type;
      s_fm_dllp.opt_upd_fc = 1'b0;
      xdlh_dllp_feature_ack = r_arb_enable;
    end
    P_FC_GRANT : begin
      s_fm_dllp.pyld = rtlh_xdlh_dllp.pyld;
      s_fm_dllp.dllp_type = rtlh_xdlh_dllp.dllp_type;
      s_fm_dllp.opt_upd_fc = rtlh_xdlh_opt_upd;
      xdlh_dllp_rtlh_ack = r_arb_enable;
    end
    P_PM_GRANT : begin
      s_fm_dllp.pyld = pm_xdlh_dllp.pyld;
      s_fm_dllp.dllp_type = (pm_xdlh_dllp.dllp_type == DUMMY) ? NOP_DLLP : pm_xdlh_dllp.dllp_type;
      s_fm_dllp.opt_upd_fc = rtlh_xdlh_opt_upd;
      xdlh_dllp_pm_ack = r_arb_enable;
    end
    P_L0P_GRANT : begin
      s_fm_dllp.pyld = xdlh_l0p_dllp.pyld;
      s_fm_dllp.dllp_type = xdlh_l0p_dllp.dllp_type;
      s_fm_dllp.opt_upd_fc = 1'b0;
      xdlh_dllp_l0p_ack.ack = r_arb_enable;
      xdlh_dllp_l0p_ack.l0p_cmd = r_l0p_cmd;
    end
    P_VENDOR_GRANT : begin
      s_fm_dllp.pyld = cdm_xdlh_dllp.pyld;
      s_fm_dllp.dllp_type = cdm_xdlh_dllp.dllp_type;
      s_fm_dllp.opt_upd_fc = 1'b0;
      xdlh_dllp_cdm_ack = r_arb_enable;
    end
    default : begin
      s_fm_dllp = '0;
      s_fm_dllp.dllp_type = NOP_DLLP;
    end
  endcase
end : dllp_PROC

// FC Init Status
always_comb begin : fc_init_PROC
  for(int i = 0; i < P_NVC; i++) begin
    if(!rtlh_fc_init_status[i])
      s_fc_init_done[i] = 1'b0;
    else if(rtlh_fc_init_status[i] && (r_fc_init_cnt == '0))
      s_fc_init_done[i] = 1'b1;
    else
      s_fc_init_done[i] = xdlh_fm_dllp_fc_init_done[i];
  end
end : fc_init_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    xdlh_fm_dllp_fc_init_done   <= #TP '0;
    xdlh_dllp_pending           <= #TP 1'b0;
  end else begin
    xdlh_dllp_pending           <= #TP (|s_dllp_req) || !s_dllp_fifo_empty;
    xdlh_fm_dllp_fc_init_done   <= #TP s_fc_init_done;
  end
end

// DLLP FIFO
assign s_dllp_fifo_push_n = !r_arb_enable;
assign s_dllp_fifo_pop_n = !(!xplh_xdlh_dllp_halt && !s_dllp_fifo_empty);

DWC_pcie_ctl_bcm65_td
 #(
    .WIDTH            (P_FIFO_WD),
    .DEPTH            (P_FIFO_DP),
    .ADDR_WIDTH       (P_FIFO_ADD_WD),
    .AE_LEVEL         (1),
    .AF_LEVEL         (P_FIFO_DP - 1),
    .REG_DELAY_TIME   (1),
    .REG_DELAY_DENOM  (10)
) u_dllp_fifo (
    .clk              (core_clk),
    .rst_n            (core_rst_n),
    .init_n           (1'b1),
    .push_req_n       (s_dllp_fifo_push_n),
    .pop_req_n        (s_dllp_fifo_pop_n),
    .diag_n           (1'b1),
    .data_in          (s_fm_dllp),
    .empty            (s_dllp_fifo_empty),
    .almost_empty     (),
    .half_full        (),
    .almost_full      (),
    .full             (s_dllp_fifo_full),
    .error            (),
    .data_out         (s_fifo_dllp)
);

// After exiting low power if PM or are in the FIFO filter them out
assign s_low_power_exit_fe = !enter_low_power && r_enter_low_power;
// After exiting recovery if L0P DLLP's are in the FIFO filter them out
assign s_rcvry_fe = !smlh_in_rcvry && r_smlh_in_rcvry;

// Depending on fifo status determine how many DLLP's to filter
always_ff @(posedge core_clk or negedge core_rst_n) begin : filt_cnt_PROC
  if(!core_rst_n) begin
    r_dllp_filt_cnt     <= #TP '0;
    r_enter_low_power   <= #TP '0;
    r_smlh_in_rcvry     <= #TP '0;
  end else begin
    r_enter_low_power   <= #TP enter_low_power;
    r_smlh_in_rcvry     <= #TP smlh_in_rcvry;
    if(s_low_power_exit_fe || s_rcvry_fe) begin
      if(s_dllp_fifo_full)
        r_dllp_filt_cnt  <= #TP P_FIFO_DP;
      else if(!s_dllp_fifo_empty)
        r_dllp_filt_cnt <= #TP (P_FIFO_DP - 1);
      else
        r_dllp_filt_cnt <= #TP '0;
    end else if((r_dllp_filt_cnt != '0) && !s_dllp_fifo_pop_n) begin
      r_dllp_filt_cnt   <= #TP r_dllp_filt_cnt - 1;
    end else begin
      r_dllp_filt_cnt   <= #TP r_dllp_filt_cnt;
    end
  end
end : filt_cnt_PROC

assign s_pm_dllp = s_fifo_dllp.dllp_type inside {PM_ENTER_L1, PM_ENTER_L23, PM_ACTIVE_STATE_REQUEST_L1, PM_REQUEST_ACK};
assign s_l0p_dllp = s_fifo_dllp.dllp_type == LINK_MANAGEMENT;
assign s_en_filt = s_pm_dllp || s_l0p_dllp;

// Filter the DLLP's after exiting recovery
always_comb begin : filt_dllp_PROC
  if(r_dllp_filt_cnt > 0) begin
    s_filt_dllp = s_en_filt ? '0 : s_fifo_dllp;
    s_filt_dllp_valid = s_en_filt ? '0 : !s_dllp_fifo_empty;
  end else begin
    s_filt_dllp = s_fifo_dllp;
    s_filt_dllp_valid = !s_dllp_fifo_empty;
  end
end : filt_dllp_PROC

assign s_pm_dllp_out = xdlh_fm_dllp_out.dllp_type inside {PM_ENTER_L1, PM_ENTER_L23, PM_ACTIVE_STATE_REQUEST_L1, PM_REQUEST_ACK};
assign s_l0p_dllp_out = xdlh_fm_dllp_out.dllp_type == LINK_MANAGEMENT;

// DLLP Output
always_ff @(posedge core_clk or negedge core_rst_n) begin : dllp_latch_PROC
  if(!core_rst_n) begin
    xdlh_fm_dllp_out.pyld         <= #TP {24{1'b0}};
    xdlh_fm_dllp_out.opt_upd_fc   <= #TP 1'b0;
    xdlh_fm_dllp_out.dllp_type    <= #TP NOP_DLLP;
    xdlh_fm_dllp_valid            <= #TP 1'b0;
  end else begin
    if(s_low_power_exit_fe && s_pm_dllp_out) begin
      xdlh_fm_dllp_out.pyld       <= #TP {24{1'b0}};
      xdlh_fm_dllp_out.opt_upd_fc <= #TP 1'b0;
      xdlh_fm_dllp_out.dllp_type  <= #TP NOP_DLLP;
      xdlh_fm_dllp_valid          <= #TP 1'b0;
    end else if(s_rcvry_fe && s_l0p_dllp_out) begin
      xdlh_fm_dllp_out.pyld       <= #TP {24{1'b0}};
      xdlh_fm_dllp_out.opt_upd_fc <= #TP 1'b0;
      xdlh_fm_dllp_out.dllp_type  <= #TP NOP_DLLP;
      xdlh_fm_dllp_valid          <= #TP 1'b0;
    end else if(!s_dllp_fifo_pop_n) begin
      xdlh_fm_dllp_out            <= #TP s_filt_dllp;  
      xdlh_fm_dllp_valid          <= #TP s_filt_dllp_valid;
    end else if(!xplh_xdlh_dllp_halt) begin
      xdlh_fm_dllp_out.pyld       <= #TP {24{1'b0}};
      xdlh_fm_dllp_out.opt_upd_fc <= #TP 1'b0;
      xdlh_fm_dllp_out.dllp_type  <= #TP NOP_DLLP;
      xdlh_fm_dllp_valid          <= #TP 1'b0;
    end
  end
end : dllp_latch_PROC

// FC Init DLLP Pushed 
always_comb begin : fc_init_push_PROC
  for(int i = 0; i < P_NVC; i++) begin
    s_fc_init_push[i] = dlp_is_vcx_init_fc(s_fm_dllp.dllp_type, i);
  end
end : fc_init_push_PROC

// FC Init DLLP Popped 
always_comb begin : fc_init_pop_PROC
  for(int i = 0; i < P_NVC; i++) begin
    s_fc_init_pop[i] = dlp_is_vcx_init_fc(xdlh_fm_dllp_out.dllp_type, i);
  end
end : fc_init_pop_PROC

// Track FC INIT DLLP's through the FIFO
always_ff @(posedge core_clk or negedge core_rst_n) begin : init_fc_track_PROC
  if(!core_rst_n)
    r_fc_init_cnt   <= #TP '0;
  else begin
    if((|s_fc_init_push) && !(|s_fc_init_pop))
      r_fc_init_cnt <= #TP r_fc_init_cnt + 1;
    else if((|s_fc_init_pop) && !(|s_fc_init_push))
      r_fc_init_cnt <= #TP r_fc_init_cnt - 1;
  end
end : init_fc_track_PROC

assign s_l0p_cmd = l0p_cmd_e'(xdlh_l0p_dllp.pyld[11:8]);

// Generate DLLP acknowledges to requestors as the DLLP's are pushed to the FIFO
always_ff @(posedge core_clk or negedge core_rst_n) begin : dllp_ack_PROC
  if(!core_rst_n) begin
    xdlh_upd_fc_sent  <= #TP '0;
    r_l0p_cmd         <= #TP l0p_cmd_e'(0);
  end else begin
    xdlh_upd_fc_sent  <= #TP !xplh_xdlh_dllp_halt && (dlp_is_update_fc(xdlh_fm_dllp_out.dllp_type) || xdlh_fm_dllp_out.opt_upd_fc);
    r_l0p_cmd         <= #TP s_l0p_cmd;
  end
end : dllp_ack_PROC



endmodule
