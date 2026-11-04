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
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_ltr_ctrl.sv#3 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the LTR extended capability registers.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_ltr_ctrl (
                   // Inputs
                   core_clk,
                   non_sticky_rst_n,
                   upstream_port,
                   ltr_m_en_fn0,
                   cfg_upd_pmcsr,
                   int_pmstate,
                   pmstate,
                   cdmpl2cfg_ltr_rq,
                   rdlh_link_up,
                   msgg2cdm_ltr_clr_msg_grant,
                   app_ltr_msg_req,
                   msg_ltr_det,
                   cfg_disable_ltr_clr_msg,
                  
                   // Outputs
                   ltrctrl_ltr_clr_msg_req,
                   ltrctrl_pmstate
                   );

// *****************************************************************************
// Declare parameters
// *****************************************************************************
   parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
   parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)

// *****************************************************************************
// Declare inputs
// *****************************************************************************
   input          core_clk;
   input          non_sticky_rst_n;
   input          upstream_port;              // Set if EP, SW upstream or PCIX upstream port
   input          ltr_m_en_fn0;               // LTR Mechanism enable, function 0
   input          cfg_upd_pmcsr;              // PMCSR update pulse
   input [1:0]    int_pmstate;                // Next function power state
   input [2:0]    pmstate;                    // Current function power state
                                              // D0uninit = 100, D0active = 000, D1 = 001, D2 = 010, D3 = 011.
   input          cdmpl2cfg_ltr_rq;           // OR'd LTR Latency port logic register requirement bits.
   input          rdlh_link_up;               // Data link status; 0=DL_Down ; 1=DL_Up
   input          msgg2cdm_ltr_clr_msg_grant; // LTR clear message grant pulse from message generator (u_msg_gen).
   input          app_ltr_msg_req;            // LTR message request - from Application interface
   input          msg_ltr_det;                // LTR message grant   - from Message Generation (msg_gen) module
   input          cfg_disable_ltr_clr_msg;    // Disable autonomous LTR clear message

// *****************************************************************************
// Declare outputs
// *****************************************************************************
   output         ltrctrl_ltr_clr_msg_req;    // LTR clear message request, valid until grant pulse received.
   output [2:0]   ltrctrl_pmstate;            // Updated function power state 

// *****************************************************************************
// Internal design
// *****************************************************************************

//--------------------------------------------------------------------
// Capture the previous PMCSR power state register value
//--------------------------------------------------------------------
   reg [2:0] pmstate_r;

   always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_seq_pmstate_r
      if (!non_sticky_rst_n) begin
        pmstate_r  <= #TP 3'b100; // D0uninit
      end else if (cfg_upd_pmcsr) begin
        pmstate_r <= #TP pmstate;
      end
   end

//--------------------------------------------------------------------
// Extract the next PMCSR.PowerState bit field
//--------------------------------------------------------------------
   parameter POWERSTATE_D0 = 2'b00;

   wire [1:0] pmcsr_powerstate;
   assign pmcsr_powerstate = int_pmstate;

//--------------------------------------------------------------------
// Generate LTR clear message request enable
//--------------------------------------------------------------------
   // Enable LTR clear message request if LTR message transmitted
   // since last data link down/up transition with either the Snoop or
   // No-Snoop requirement LTR message bits set.
   // Note: When the LTR clear message is transmitted cdmrl2cfg_ltr_rq -> 0.
   // LTR clear message not enabled if alternate functions are directed to 
   // a non-D0 state.
   reg clr_ltr_msg_req_en;
   always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_seq_rq_r
      if (!non_sticky_rst_n) begin
        clr_ltr_msg_req_en <= #TP 1'b0;
      end else if (cdmpl2cfg_ltr_rq && rdlh_link_up) begin 
        clr_ltr_msg_req_en <= #TP 1'b1; 
      end else begin
        clr_ltr_msg_req_en <= #TP 1'b0; 
      end
   end

//--------------------------------------------------------------------
// Detect LTR Mechanism enable/disable transition
//--------------------------------------------------------------------
   reg ltr_m_en_fn0_r;
   always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_seq_ltr_m_en_fn0_r
      if (!non_sticky_rst_n) begin
        ltr_m_en_fn0_r <= #TP 1'b0;
      end else begin
        ltr_m_en_fn0_r <= #TP ltr_m_en_fn0;
      end
   end
  
wire ltr_m_en_fn0_fedge_det;
assign ltr_m_en_fn0_fedge_det = (~ltr_m_en_fn0 & ltr_m_en_fn0_r);

// -----------------------------------------------------------------------
// There is a possibility of a race condition occurring if a CfgWr to
// either disable LTR Messaging (cfg_ltr_m_en goes low) or enter D3 (
// cfg_upd_pmcsr pulse when pmcsr_powerstate != POWERSTATE_D0) while the
// application requests to send a message with Requirement bit = 1. To
// prevent this, the pulses on ltr_m_en_fn0_fedge_det or cfg_upd_pmcsr must
// be stretched if app_ltr_msg_req is asserted at the same tiem.
// ----------------------------------------------------------------------
reg  r_ltr_msg_grant;        // registered msg_ltr_det.
reg  r_ltr_msg_grant_d;      // 2 clock cycle delayed msg_ltr_det.

   always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_ltr_msg_grant_delays
      if (!non_sticky_rst_n) begin
        r_ltr_msg_grant   <= #TP 1'b0;
        r_ltr_msg_grant_d <= #TP 1'b0;
      end else begin
        r_ltr_msg_grant   <= #TP msg_ltr_det;
        r_ltr_msg_grant_d <= #TP r_ltr_msg_grant;
      end
   end

wire app_ltr_msg_win;        // full window where Application could assert request while Wire is clearing LTR Enable
reg  r_ltr_msg_win;          // part of window where Application could assert request while Wire is clearing LTR Enable

wire int_ltr_m_en_fedge_det;  // LTR Message Enabled, falling edge detect, possibly stretched
reg  r_ltr_m_en_fedge_det;    // stretched LTR Message Enabled, falling edge detect, if it occurs while app_ltr_msg_win is asserted.

   always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_ltr_m_en_window
      if (!non_sticky_rst_n) begin
        r_ltr_msg_win <= #TP 1'b0;
      end else if(app_ltr_msg_req) begin
        r_ltr_msg_win <= #TP 1'b1;
      end else if(r_ltr_msg_grant_d) begin
        r_ltr_msg_win <= #TP 1'b0;
      end
   end

assign app_ltr_msg_win = app_ltr_msg_req | r_ltr_msg_win;

   always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_ltr_m_en_fedge_det_stretch
      if (!non_sticky_rst_n) begin
        r_ltr_m_en_fedge_det <= #TP 1'b0;
      end else if(ltr_m_en_fn0_fedge_det && app_ltr_msg_win) begin
        r_ltr_m_en_fedge_det <= #TP 1'b1;
      end else if(!app_ltr_msg_win) begin
        r_ltr_m_en_fedge_det <= #TP 1'b0;
      end
   end
  
// stretched edge detect signal when app_ltr_msg_req asserted at the same
// time; otherwise it remains as a single cycle pulse:
assign int_ltr_m_en_fedge_det = ltr_m_en_fn0_fedge_det | r_ltr_m_en_fedge_det;

reg  r_cfg_upd_pmcsr_nond0;
wire cfg_upd_pmcsr_nond0;
wire int_cfg_upd_pmcsr_nond0;

assign cfg_upd_pmcsr_nond0 = (pmcsr_powerstate != POWERSTATE_D0) ? cfg_upd_pmcsr : 1'b0;

   always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_cfg_upd_pmcsr_nond0_stretch
      if (!non_sticky_rst_n) begin
        r_cfg_upd_pmcsr_nond0 <= #TP 1'b0;
      end else if(cfg_upd_pmcsr_nond0 && app_ltr_msg_win) begin
        r_cfg_upd_pmcsr_nond0 <= #TP 1'b1;
      end else if(!app_ltr_msg_win) begin
        r_cfg_upd_pmcsr_nond0 <= #TP 1'b0;
      end
   end
  
// stretched edge detect signal when app_ltr_msg_req asserted at the same
// time; otherwise it remains as a single cycle pulse:
assign int_cfg_upd_pmcsr_nond0 = cfg_upd_pmcsr_nond0 | r_cfg_upd_pmcsr_nond0;


//--------------------------------------------------------------------
//  LTR Clear Message Control FSM
//--------------------------------------------------------------------
   // Encoding for state machine
   parameter ST_IDLE             = 2'b00; // Idle
   parameter ST_SEND_LTR_CLR_MSG = 2'b01; // Send LTR clear message

   //-----------------------------------------------------------------
   // FSM sequential process
   //-----------------------------------------------------------------
   reg   [1:0] ltrctrl_current_state;
   reg   [1:0] ltrctrl_next_state;

   always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_seq_ltrctrl_fsm
      if (!non_sticky_rst_n) begin
        ltrctrl_current_state <= #TP ST_IDLE;
      end else begin
        ltrctrl_current_state <= #TP ltrctrl_next_state; 
      end
   end

   //-----------------------------------------------------------------
   // FSM combinational process
   //-----------------------------------------------------------------
   always @(*) begin : proc_comb_ltrctrl_fsm

      ltrctrl_next_state = ltrctrl_current_state;

      case (ltrctrl_current_state)
          ST_IDLE             : begin
            // If the function is directed to a non-D0 state or the LTR Mechanism is
            // disabled since the last DL_Down/Up transition and LTR active then 
            // send LTR clear message. 
            // PMCSR.PowerState bit field updated after LTR clear message transmitted.
            // LTR clear message transmitted upstream only (EP/SW).
            if (upstream_port && clr_ltr_msg_req_en && !cfg_disable_ltr_clr_msg) begin
              //if ((cfg_upd_pmcsr && (pmcsr_powerstate != POWERSTATE_D0)) 
              if (int_cfg_upd_pmcsr_nond0 || int_ltr_m_en_fedge_det) begin
                ltrctrl_next_state = ST_SEND_LTR_CLR_MSG;
              end
            end
          end
          ST_SEND_LTR_CLR_MSG : begin
            // Wait for the acceptance of the LTR clear message request by the XADM
            if (msgg2cdm_ltr_clr_msg_grant) begin
                ltrctrl_next_state = ST_IDLE;
            end
          end
          default             : begin
            ltrctrl_next_state = ST_IDLE;
          end
      endcase
   end

   //-----------------------------------------------------------------
   // FSM outputs
   //-----------------------------------------------------------------
   // Send LTR clear message request
   wire ltrctrl_ltr_clr_msg_req;
   assign ltrctrl_ltr_clr_msg_req = (ltrctrl_current_state==ST_SEND_LTR_CLR_MSG);

   // Hold pmstate until LTR clear message sent 
   wire ltrctrl_upd_ltrctrl_pmstate;
   assign ltrctrl_hold_pmstate = ((ltrctrl_current_state==ST_SEND_LTR_CLR_MSG) && ltr_m_en_fn0_r);

   // Update pmstate 
   reg [2:0] ltrctrl_pmstate;
   always @(*) begin : proc_comb_pmstate_mux
      if (ltrctrl_hold_pmstate) begin
       ltrctrl_pmstate = pmstate_r; // Hold previous PowerState value until LTR clear message transmitted
      end else begin
       ltrctrl_pmstate = pmstate; // Transition to non-D0 state
      end
   end

//--------------------------------------------------------------------
// Enumerate FSM states
//--------------------------------------------------------------------
   `ifndef SYNTHESIS
   wire [16*8:1] LTR_CTRL_CURRENT_STATE;
   assign LTR_CTRL_CURRENT_STATE = (ltrctrl_current_state == ST_IDLE) ? "ST_IDLE                        ":
                                   (ltrctrl_current_state == ST_SEND_LTR_CLR_MSG) ? "ST_SEND_LTR_CLR_MSG":
                                   "UNDEF";
   `endif // SYNTHESIS

endmodule
