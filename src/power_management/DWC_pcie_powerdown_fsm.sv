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
// ---    $Revision: #23 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/DWC_pcie_powerdown_fsm.sv#23 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module contains an FSM which drives the powerdown signals
// --- during certain low power negotiations.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
 
 module DWC_pcie_powerdown_fsm
  // Parameters
  #(
    parameter TP          = `TP,
    parameter PDWN_WIDTH  = 4,
    parameter P0          = 4'b0000,
    parameter P1          = 4'b0010,
    parameter P2          = 4'b0011,
    parameter P1CPM       = `CX_PIPE43_P1CPM_ENCODING,
    parameter P1_1        = `CX_PIPE43_P1_1_ENCODING,
    parameter P1_2        = `CX_PIPE43_P1_2_ENCODING
  ) 
                                (
    // Inputs
    input                                 aux_clk, // aux_clk
    input                                 pwr_rst_n, // power on reset
    input                                 p1cpm_hs_done, // Phystatus pulse synchronous to aux_clk
    input                                 p1_hs_done, // pulse converter busy indication
    input                                 p2_hs_done, // pulse converter busy indication
    input                                 aux_clk_active,
    input                                 l1sub_exit_next,  // L1.Exit is next state for L1 Sub-state FSM
    input                                 l1sub_l11_next, // L1.1 is next state for L1 Sub-state FSM
    input                                 l1sub_l12_next, // L1.2 is next state for L1 Sub-state FSM
    input                                 l1sub_l1_u_next, // L1.Idle is next for L1 sub-state FSM
    input                                 l1sub_abort_next, // L1 sub-state entry is aborted
    input                                 pm_l1sub_clk_req_n, // CLKREQ# driven by L1 sub-states
    input                                 trgt_l1sub, // L1 sub-state is requested and pm state is L1
    input                                 trgt_l1cpm, // L1CPM is requested and pm state is L1
    input                                 pm_linkst_l23rdy, // PM state is L23RDY
    input                                 pm_linkst_in_l1, // PM state is L1
    input                                 pm_req_exit_l1, // Includes the valid L1 exit conditions
    input                                 smlh_in_l1, // LTSSM initiates the transition to L1
    input [(PDWN_WIDTH - 1) : 0]          pm_cfg_phy_powerdown_p2_options, // Drive P2.NoBeacon or P2
    input                                 aux_sync_phystatus, // Phystatus level synchronized to aux_clk for Asynchronous handshake 
    input                                 aux_sync_phystatus_low, // Phystatus level synchronized to aux_clk for Asynchronous handshake 
    input [(PDWN_WIDTH - 1) : 0]          pm_powerdown, // PowerDown driven by pm_ctrl
    input                                 pm_req_exit_p2, // request to transition from p2 to p1
    input                                 perst_n, // fundamental reset request
    input                                 cfg_pl_l1sub_fast_exit, // if set to 1 indicates that the reference clock remains available during L1 sub-states negotiation
    input                                 l1sub_req_p1cpm, // L1.N.Entry is next state for L1 Sub-state FSM
    input                                 pd_maxpclkack_n_rise_det,// detect rising edge in pd_maxpclkack_n
    input                                 pd_maxpclkack_n_fall_det, // detect falling edge in pd_maxpclkack_n
    input                                 pm_perst_powerdown, // Indicate to drive specific powerdown for perst rst
    // Outputs
    output logic                          pd_fsm_prev_p0_r, // Previous state was P0
    output logic                          pd_fsm_pclkack_n_r, // pclkack_n driven to the L1 sub-state FSM for L1N entry process
    output logic                          pd_fsm_pclkreq_n_r, // local_ref_clkreq_n for reference clock removal
    output logic  [(PDWN_WIDTH - 1) : 0]  pd_fsm_powerdown_r, // Powerdown command for the PHY
    output logic                          pd_fsm_drive_pd_r, // Powerdown is being driven by the FSM
    output logic                          pd_fsm_block_phystatus_r, // Block update of current_powerdown in rmlh
    output logic  [1 : 0]                 pd_fsm_en_pulse_det_r, // Enable Phystatus detection logic in pipe_adapter
    output logic                          pd_fsm_powerdown_p1, // powerdown is P1
    output logic                          pd_fsm_powerdown_no_clk // powerdown is P1CPM, P1_1 or P1_2, in which ref clk will be removed
    ,
    output logic                          pd_fsm_asyncpowerchange_ack_r, // Asynchronous power change acknowledge to the PHY
    output logic                          pd_fsm_en_async_hs_r // enable asynchronous handshake logic
    ,
    output logic                          pd_fsm_pg_ack_r, // Acknowledge for PMU FSM to proceed to gate the power
    output logic                          pd_fsm_txcommonmode_disable_r, // Disable Txcommonmode
    output logic                          pd_fsm_rxelecidle_disable_r // Disable electrical idle detection
    ,
    output logic                          pd_fsm_sel_aux_clk_r // allow switching of aux_clk only on entry to P1.CPM when the target is either L1 sub-states or L1.CPM
    ,
    output logic                          mac_phy_maxpclkreq_n, // drive maxpaclkreq_n
    output logic                          pd_fsm_maxpclk_removed, // indicate that MAXPCLK is removed
    output logic                          pd_fsm_maxpclk_back_on // indicate that MAXPCLK is turned on in P1CPM/P1.1/P1.2

);

// ----------------------------------------------------------------------------
// Declarations
// ----------------------------------------------------------------------------

import DWC_pcie_pm_pkg::pd_fsm_state_e;
import DWC_pcie_pm_pkg::IDLE;
import DWC_pcie_pm_pkg::PD_P1;
import DWC_pcie_pm_pkg::PD_P2;
import DWC_pcie_pm_pkg::PD_P1_CPM;
import DWC_pcie_pm_pkg::PD_P1_1;
import DWC_pcie_pm_pkg::PD_P1_2;
import DWC_pcie_pm_pkg::PD_TPOWER_ON;
import DWC_pcie_pm_pkg::ASYNC_HS_ENTER;
import DWC_pcie_pm_pkg::ASYNC_HS_EXIT;
import DWC_pcie_pm_pkg::WAIT_PM_L1;
import DWC_pcie_pm_pkg::MAXPCLK_OFF;
import DWC_pcie_pm_pkg::MAXPCLK_ON;
pd_fsm_state_e state_r, next_state_b;

// ----------------------------------------------------------------------------
// Register types
// ----------------------------------------------------------------------------
logic int_prev_p1cpm_r; // Previous state was P1.CPM
logic int_p1_hs_done_r;
logic int_lp_nego_r; // l1cpm or l1 sub-state negotiation
logic int_p1cpm_hs_done_r;
logic int_p1sub_hs_done_r;
logic int_prev_p1_r;
logic int_prev_p1sub_r;
logic int_smlh_in_l1_r;
logic int_pm_linkst_l23rdy_r;
logic int_p2_hs_done_r;
logic int_prev_maxpclk_on_r;
logic int_prev_maxpclk_off_r;
logic int_pm_req_exit_p2;
logic current_pwdw_p1cpm;
logic current_pwdw_p11;
logic current_pwdw_p12;


// ----------------------------------------------------------------------------
// Wire types
// ----------------------------------------------------------------------------
logic int_p0_p1cpm_en;
logic int_smlh_in_l1_re;
logic int_pm_linkst_l23rdy_re;
logic int_l1sub_fast_exit;

// Transition is direct to P1.CPM
assign int_p0_p1cpm_en = 1'b0;

assign current_pwdw_p1cpm = pd_fsm_powerdown_r == P1CPM && !pd_fsm_rxelecidle_disable_r;
assign current_pwdw_p11   = pd_fsm_powerdown_r == P1_1 && pd_fsm_rxelecidle_disable_r && !pd_fsm_txcommonmode_disable_r;
assign current_pwdw_p12   = pd_fsm_powerdown_r == P1_2 && pd_fsm_rxelecidle_disable_r && pd_fsm_txcommonmode_disable_r;

assign int_l1sub_fast_exit = (|trgt_l1sub) && cfg_pl_l1sub_fast_exit;

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : pd_fsm_sync_PROC
  if(!pwr_rst_n) begin
    state_r                 <= #TP IDLE;
    int_smlh_in_l1_r        <= #TP 1'b0;
    int_pm_linkst_l23rdy_r  <= #TP 1'b0;
  end
  else begin
    // fundamental reset puts the FSM back to its IDLE state
    if(pm_perst_powerdown) begin
      state_r                 <= #TP IDLE;
    end else begin
      state_r                 <= #TP next_state_b;
    end
    int_smlh_in_l1_r        <= #TP smlh_in_l1;
    int_pm_linkst_l23rdy_r  <= #TP pm_linkst_l23rdy;
  end
end : pd_fsm_sync_PROC

assign int_smlh_in_l1_re = !int_smlh_in_l1_r && smlh_in_l1;
assign int_pm_linkst_l23rdy_re = !int_pm_linkst_l23rdy_r && pm_linkst_l23rdy;


always_comb begin : pd_fsm_PROC
    case(state_r)
    IDLE : begin // IDLE
      // L1 transition initiated by LTSSM wait until PM state is L1 before
      // driving powerdown to P1
      if(int_smlh_in_l1_re)
        next_state_b = WAIT_PM_L1;
      // P0->P2
      else if(int_pm_linkst_l23rdy_re)
        next_state_b = PD_P2;
      else
        next_state_b = IDLE;
    end
    WAIT_PM_L1 : begin
      if(pm_linkst_in_l1)
        next_state_b = PD_P1;
      else
        next_state_b = WAIT_PM_L1;
    end
    PD_P1 : begin
      // P1->P0 (exit from L1)
      if(!(trgt_l1sub || trgt_l1cpm) && pm_req_exit_l1 && int_p1_hs_done_r)
        next_state_b = IDLE;
      // P1->P1.CPM
      else if(int_lp_nego_r && int_p1_hs_done_r && !int_p0_p1cpm_en) begin
        if(l1sub_l1_u_next) begin
          next_state_b = IDLE;
        end
        else if (int_l1sub_fast_exit) begin
          if(l1sub_req_p1cpm)
            next_state_b = PD_P1_CPM;
          else
            next_state_b = PD_P1;
        end
        // move directly to P1.CPM at the beginning of the L1 sub-states negotiation
        else
          next_state_b = PD_P1_CPM;
      end
      // P1->P0 after L1 sub-states exit (wait Tpower_on)
      else if(l1sub_exit_next && int_p1_hs_done_r)
        next_state_b = PD_TPOWER_ON;
      // P1->P0 after aborted L1 sub-states wait L1.Idle 
      else if(l1sub_l1_u_next && int_p1_hs_done_r)
        next_state_b = IDLE;
      else
        next_state_b = PD_P1;
    end
    PD_P2 : begin
      // P2->MAXPCLK_OFF after phystatus is received
      // int_pm_req_exit_p2 is the latch of pm_req_exit_p2, won't be deasserted until exit P2
      // !pd_fsm_maxpclk_back_on is used to avoid go back to MAXPCLK_OFF after exit triggered.
      if(int_p2_hs_done_r && !pd_fsm_maxpclk_removed && !(pm_req_exit_p2 || int_pm_req_exit_p2) && !pd_fsm_maxpclk_back_on) begin
          next_state_b = MAXPCLK_OFF;
      // P2->MAXPCLK_ON after l2 exit is triggered
      end else if ( (pm_req_exit_p2 || int_pm_req_exit_p2 ) 
                    && int_p2_hs_done_r && pd_fsm_maxpclk_removed) begin
          next_state_b = MAXPCLK_ON;
      end else begin
      // P2->P1
      if( (pm_req_exit_p2 || int_pm_req_exit_p2 )
 && !aux_clk_active)
        next_state_b = IDLE;
      else
        next_state_b = PD_P2;
      end
    end
    PD_P1_CPM : begin

      // P1.CPM->MAXPCLK_OFF after phystatus is received
      if(int_p1cpm_hs_done_r && !pd_fsm_maxpclk_removed && !l1sub_exit_next
        && !l1sub_l1_u_next && !l1sub_abort_next
        ) begin
          next_state_b = MAXPCLK_OFF;
      // P1.CPM->MAXPCLK_ON after l1 exit is triggered
      end else if (int_p1cpm_hs_done_r && pd_fsm_maxpclk_removed 
                   && (l1sub_exit_next
                   || l1sub_l1_u_next || l1sub_abort_next
                   )) begin
          next_state_b = MAXPCLK_ON;
      end else begin

      // P1.CPM->P1 after L1 sub-states exit (wait Tpower_on)
      if(l1sub_exit_next && int_p1cpm_hs_done_r)
        next_state_b = PD_TPOWER_ON;
      // P1.CPM->P1 after aborted L1 sub-states wait L1.Idle 
      else if((l1sub_l1_u_next || l1sub_abort_next) && int_p1cpm_hs_done_r && !aux_clk_active)
        next_state_b = PD_P1;
      // P1.CPM->P1.2
      else if(l1sub_l12_next && int_p1cpm_hs_done_r)
        next_state_b = PD_P1_2;
      // P1.CPM->P1.1
      else if(l1sub_l11_next && int_p1cpm_hs_done_r)
        next_state_b = PD_P1_1;

      else
        next_state_b = PD_P1_CPM;

      end

    end
    PD_TPOWER_ON : begin
      if(!l1sub_exit_next && (pd_fsm_powerdown_r == P1CPM) && !aux_clk_active)
        next_state_b = PD_P1;
      else if(!l1sub_exit_next && (pd_fsm_powerdown_r == P1))
        next_state_b = IDLE;
      else
        next_state_b = PD_TPOWER_ON;
    end
    PD_P1_1 : begin
      // Perform asynchronous Phystatus handshake with the PHY
      if(!int_p1sub_hs_done_r && aux_sync_phystatus) begin
          next_state_b = ASYNC_HS_ENTER;
      end else begin
      // P1.1->MAXPCLK_OFF after phystatus is received
      if(int_p1sub_hs_done_r && !pd_fsm_maxpclk_removed && !(l1sub_l1_u_next || l1sub_exit_next)) begin
          next_state_b = MAXPCLK_OFF;
      // P1.1->MAXPCLK_ON after l1 exit is triggered
      end else if ((l1sub_l1_u_next || l1sub_exit_next) && int_p1sub_hs_done_r && pd_fsm_maxpclk_removed) begin
          next_state_b = MAXPCLK_ON;
      end else begin
      if((l1sub_l1_u_next || l1sub_exit_next) && int_p1sub_hs_done_r && !aux_clk_active) begin
      // P1.1->P1
        next_state_b = PD_P1;
      end
      else
        next_state_b = PD_P1_1;
      end
      end
    end
    PD_P1_2 : begin
      // Perform asynchronous Phystatus handshake with the PHY
      if(!int_p1sub_hs_done_r && aux_sync_phystatus) begin
          next_state_b = ASYNC_HS_ENTER;
      end else begin
      // P1.2->MAXPCLK_OFF after phystatus is received
      if(int_p1sub_hs_done_r && !pd_fsm_maxpclk_removed && !(l1sub_l1_u_next || l1sub_exit_next)) begin
          next_state_b = MAXPCLK_OFF;
      // P1.2->MAXPCLK_ON after l1 exit is triggered
      end else if ((l1sub_l1_u_next || l1sub_exit_next) && int_p1sub_hs_done_r && pd_fsm_maxpclk_removed) begin
          next_state_b = MAXPCLK_ON;
      end else begin
      if((l1sub_l1_u_next || l1sub_exit_next) && int_p1sub_hs_done_r && !aux_clk_active) begin
      // P1.2->P1
        next_state_b = PD_P1;
      end
      else
        next_state_b = PD_P1_2;
      end
      end
    end
    ASYNC_HS_ENTER : begin
      if(aux_sync_phystatus_low)
        next_state_b = ASYNC_HS_EXIT;
      else
        next_state_b = ASYNC_HS_ENTER;
    end
    ASYNC_HS_EXIT : begin
      if(current_pwdw_p11)
        next_state_b = PD_P1_1;
      else
        next_state_b = PD_P1_2;
    end
    MAXPCLK_OFF : begin
      if (pd_maxpclkack_n_rise_det) begin
        if(int_prev_p1cpm_r)
          next_state_b = PD_P1_CPM;
        else
          next_state_b = PD_P2;
      end else begin
        next_state_b = MAXPCLK_OFF;
      end
    end
    MAXPCLK_ON : begin
      if (pd_maxpclkack_n_fall_det) begin
        if(int_prev_p1cpm_r)
          next_state_b = PD_P1_CPM;
        else if(current_pwdw_p11)
          next_state_b = PD_P1_1;
        else if(current_pwdw_p12)
          next_state_b = PD_P1_2;
        else
          next_state_b = PD_P2;
      end else begin
        next_state_b = MAXPCLK_ON;
      end
    end
    default :
      next_state_b = IDLE;
  endcase
end : pd_fsm_PROC

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : pd_fsm_outputs_PROC
  if(!pwr_rst_n) begin
    int_p1_hs_done_r              <= #TP 1'b0;
    int_lp_nego_r                 <= #TP 1'b0;
    int_p1cpm_hs_done_r           <= #TP 1'b0;
    int_p1sub_hs_done_r           <= #TP 1'b0;
    pd_fsm_pclkack_n_r            <= #TP 1'b0;
    pd_fsm_pclkreq_n_r            <= #TP 1'b0;
    pd_fsm_powerdown_r            <= #TP P1;
    pd_fsm_drive_pd_r             <= #TP 1'b0;
    pd_fsm_block_phystatus_r      <= #TP 1'b0;
    pd_fsm_en_pulse_det_r         <= #TP 2'b00;
    int_prev_p1_r                 <= #TP 1'b0;
    pd_fsm_prev_p0_r              <= #TP 1'b0;
    int_prev_p1cpm_r              <= #TP 1'b0;
    int_prev_p1sub_r              <= #TP 1'b0;
    pd_fsm_asyncpowerchange_ack_r <= #TP 1'b0;
    pd_fsm_en_async_hs_r          <= #TP 1'b0;
    pd_fsm_pg_ack_r               <= #TP 1'b0;
    pd_fsm_rxelecidle_disable_r   <= #TP 1'b0;
    pd_fsm_txcommonmode_disable_r <= #TP 1'b0;
    pd_fsm_sel_aux_clk_r          <= #TP 1'b0;
    int_p2_hs_done_r              <= #TP 1'b0;
    mac_phy_maxpclkreq_n          <= #TP 1'b0;
    pd_fsm_maxpclk_removed        <= #TP 1'b0;
    int_prev_maxpclk_on_r         <= #TP 1'b0;
    int_prev_maxpclk_off_r        <= #TP 1'b0;
    pd_fsm_maxpclk_back_on        <= #TP 1'b0;
    int_pm_req_exit_p2            <= #TP 1'b0;
  end
  else begin
    int_lp_nego_r                 <= #TP 1'b0;
    pd_fsm_pclkack_n_r            <= #TP 1'b0;
    pd_fsm_en_async_hs_r          <= #TP 1'b0;
    pd_fsm_sel_aux_clk_r          <= #TP 1'b0;
    case(next_state_b)
      IDLE : begin
        int_p1_hs_done_r              <= #TP 1'b0;
        int_lp_nego_r                 <= #TP 1'b0;
        int_p1cpm_hs_done_r           <= #TP 1'b0;
        int_p1sub_hs_done_r           <= #TP 1'b0;
        pd_fsm_pclkack_n_r            <= #TP 1'b0;
        pd_fsm_pclkreq_n_r            <= #TP 1'b0;
        pd_fsm_powerdown_r            <= #TP pm_powerdown;
        pd_fsm_drive_pd_r             <= #TP 1'b0;
        pd_fsm_prev_p0_r              <= #TP 1'b0;
        int_prev_p1_r                 <= #TP 1'b0;
        int_prev_p1cpm_r              <= #TP 1'b0;
        int_prev_p1sub_r              <= #TP 1'b0;
        pd_fsm_asyncpowerchange_ack_r <= #TP 1'b0;
        pd_fsm_en_async_hs_r          <= #TP 1'b0;
        pd_fsm_pg_ack_r               <= #TP 1'b0;
        pd_fsm_rxelecidle_disable_r   <= #TP 1'b0;
        pd_fsm_txcommonmode_disable_r <= #TP 1'b0;
        pd_fsm_sel_aux_clk_r          <= #TP 1'b0;
        pd_fsm_en_pulse_det_r[0]      <= #TP 1'b0;
        int_p2_hs_done_r              <= #TP 1'b0;
        mac_phy_maxpclkreq_n          <= #TP 1'b0;
        pd_fsm_maxpclk_removed        <= #TP 1'b0;
        int_prev_maxpclk_on_r         <= #TP 1'b0;
        int_prev_maxpclk_off_r        <= #TP 1'b0;
        pd_fsm_maxpclk_back_on        <= #TP 1'b0;
        int_pm_req_exit_p2            <= #TP 1'b0;
        // deassert these signals synchronous to core_clk
        if( smlh_in_l1 ) begin
          pd_fsm_block_phystatus_r    <= #TP pd_fsm_block_phystatus_r;
        end else begin
          pd_fsm_en_pulse_det_r[1]    <= #TP 1'b0;
          pd_fsm_block_phystatus_r    <= #TP 1'b0;
        end    
      end
      WAIT_PM_L1 : begin
        pd_fsm_drive_pd_r <= #TP 1'b1;
        pd_fsm_powerdown_r <= #TP P0;
        pd_fsm_prev_p0_r <= #TP 1'b1;
        pd_fsm_pclkreq_n_r <= #TP pm_l1sub_clk_req_n;
      end
      PD_P1 : begin
        if(pd_fsm_prev_p0_r) begin
          int_lp_nego_r <= #TP (trgt_l1sub || trgt_l1cpm);
        end else begin
          int_lp_nego_r <= #TP int_lp_nego_r;
        end
        int_prev_p1_r <= #TP 1'b1;
        pd_fsm_powerdown_r <= #TP P1;
        int_p1sub_hs_done_r <= #TP 1'b0;
        pd_fsm_pg_ack_r <= #TP 1'b0;
        pd_fsm_rxelecidle_disable_r <= #TP 1'b0;
        pd_fsm_txcommonmode_disable_r <= #TP 1'b0;
        pd_fsm_pclkreq_n_r <= #TP pm_l1sub_clk_req_n;
        int_p1cpm_hs_done_r <= #TP 1'b0;
        int_prev_p1sub_r <= #TP 1'b0;

        // Enable the Phystatus pulse detection on P0->P1 transitions
        if(pd_fsm_prev_p0_r) begin
          pd_fsm_en_pulse_det_r <= #TP 2'b01;
        end else if(int_prev_p1sub_r) begin
        // Enable the Phystatus pulse detection after exiting P1.CPM
          pd_fsm_en_pulse_det_r <= #TP 2'b10;
        end else if(int_prev_p1cpm_r) begin
        // Enable the Phystatus pulse detection after exiting P1.CPM
          pd_fsm_en_pulse_det_r <= #TP 2'b10;
        end else begin
          pd_fsm_en_pulse_det_r <= #TP pd_fsm_en_pulse_det_r;
        end
        
        // P1 handshake with the PHY completed
        if(p1_hs_done) begin
          pd_fsm_sel_aux_clk_r <= #TP 1'b1;
          int_p1_hs_done_r <= #TP 1'b1;
          pd_fsm_block_phystatus_r <= #TP 1'b1;
          if(pd_fsm_prev_p0_r) begin
            pd_fsm_prev_p0_r <= #TP 1'b0;
          end else if(int_prev_p1cpm_r) begin
            int_prev_p1cpm_r <= #TP 1'b0;
          end
        end
      end
      PD_P2 : begin
        pd_fsm_powerdown_r <= #TP pm_cfg_phy_powerdown_p2_options;
        if(p2_hs_done) begin
          int_p2_hs_done_r <= #TP 1'b1;
        end else begin
          int_p2_hs_done_r <= #TP int_p2_hs_done_r;
        end
        if(int_prev_maxpclk_on_r) begin 
          pd_fsm_maxpclk_back_on <= #TP 1'b1;
          pd_fsm_maxpclk_removed <= #TP 1'b0;
        end
        int_prev_maxpclk_on_r <= #TP 1'b0;
        if (pd_fsm_maxpclk_removed && pm_req_exit_p2) begin
          int_pm_req_exit_p2 <= #TP 1'b1;
        end
      end
      PD_P1_CPM : begin
        pd_fsm_powerdown_r <= #TP P1CPM;
        int_p1_hs_done_r <= #TP 1'b0;
        int_prev_p1cpm_r <= #TP 1'b1;
        pd_fsm_drive_pd_r <= #TP 1'b1;
        int_p1sub_hs_done_r <= #TP 1'b0;
        pd_fsm_pg_ack_r <= #TP 1'b0;
        pd_fsm_rxelecidle_disable_r <= #TP 1'b0;
        pd_fsm_txcommonmode_disable_r <= #TP 1'b0;
        pd_fsm_block_phystatus_r <= #TP 1'b1;
        if(int_prev_maxpclk_on_r) begin 
          pd_fsm_maxpclk_back_on <= #TP 1'b1;
          pd_fsm_maxpclk_removed <= #TP 1'b0;
        end else begin
          if (!pd_fsm_maxpclk_removed
              && (l1sub_exit_next 
                  || l1sub_l1_u_next || l1sub_abort_next 
                 ) 
             ) begin
            // For early exit from l1sub, turn off aux clk before exit to P1.
            pd_fsm_sel_aux_clk_r <= #TP 1'b0;
          end else begin
            // In PCLK as PHY input, only select core clk when maxpclk is back on after exit from MAXPCLK_ON
            if (pd_fsm_maxpclk_back_on)
                pd_fsm_sel_aux_clk_r <= #TP 1'b0;
            else 
                pd_fsm_sel_aux_clk_r <= #TP 1'b1;
          end
        end
        int_prev_maxpclk_on_r <= #TP 1'b0;

        // Detect Phystatus handshake
        if(int_prev_p1sub_r) begin
          pd_fsm_pclkreq_n_r <= #TP 1'b0;
          pd_fsm_en_async_hs_r <= #TP 1'b1;
        end else if(int_prev_p1_r) begin
          pd_fsm_en_pulse_det_r[0] <= #TP 1'b1;
          if(p1cpm_hs_done) begin
            int_prev_p1_r <= #TP 1'b0;
            int_p1cpm_hs_done_r <= #TP 1'b1;
          // In fast exit mode dont wait for Phystatus to de-assert CLKREQ
          end else begin
          end
        end else if(int_prev_maxpclk_off_r) begin 
          // This is to gaurantee ref clk is back on when maxpclk is on.
          pd_fsm_pclkreq_n_r <= #TP 1'b1; 
          pd_fsm_pclkack_n_r <= #TP 1'b1;
        end else begin
          int_p1cpm_hs_done_r <= #TP int_p1cpm_hs_done_r;
          pd_fsm_pclkreq_n_r <= #TP pd_fsm_pclkreq_n_r;
          pd_fsm_pclkack_n_r <= #TP pd_fsm_pclkack_n_r;
        end
        if (int_prev_maxpclk_off_r) begin
          int_prev_maxpclk_off_r <= #TP 1'b0;
        end
      end
      PD_P1_1 : begin
        if (pd_fsm_maxpclk_back_on)
            pd_fsm_sel_aux_clk_r <= #TP 1'b0;
        else 
            pd_fsm_sel_aux_clk_r <= #TP 1'b1;
        pd_fsm_pclkack_n_r <= #TP 1'b1;
        pd_fsm_en_pulse_det_r[0] <= #TP 1'b0;
        int_prev_p1_r <= #TP 1'b0;
        pd_fsm_prev_p0_r <= #TP 1'b0;
        pd_fsm_powerdown_r <= #TP P1_1;
        int_prev_p1sub_r <= #TP 1'b1;
        pd_fsm_rxelecidle_disable_r <= #TP 1'b1;
        int_p1cpm_hs_done_r <= #TP 1'b0;
        pd_fsm_en_async_hs_r <= #TP 1'b1;
        // Disable the Phystatus pulse detection after exiting P1.CPM
        if(int_prev_p1cpm_r) begin
          pd_fsm_en_pulse_det_r[0] <= #TP 1'b0;
          int_prev_p1cpm_r <= #TP 1'b0;
        end
        if(int_prev_maxpclk_on_r) begin 
          pd_fsm_maxpclk_back_on <= #TP 1'b1;
          pd_fsm_maxpclk_removed <= #TP 1'b0;
        end
        int_prev_maxpclk_on_r <= #TP 1'b0;
      end
      PD_P1_2 : begin
        if (pd_fsm_maxpclk_back_on)
            pd_fsm_sel_aux_clk_r <= #TP 1'b0;
        else 
            pd_fsm_sel_aux_clk_r <= #TP 1'b1;
        pd_fsm_pclkack_n_r <= #TP 1'b1;
        pd_fsm_en_pulse_det_r[0] <= #TP 1'b0;
        int_prev_p1_r <= #TP 1'b0;
        pd_fsm_prev_p0_r <= #TP 1'b0;
        pd_fsm_powerdown_r <= #TP P1_2;
        int_prev_p1sub_r <= #TP 1'b1;
        pd_fsm_rxelecidle_disable_r <= #TP 1'b1;
        pd_fsm_txcommonmode_disable_r <= #TP 1'b1;
        int_p1cpm_hs_done_r <= #TP 1'b0;
        pd_fsm_en_async_hs_r <= #TP 1'b1;
        
        // Disable the Phystatus pulse detection after exiting P1.CPM
        if(int_prev_p1cpm_r) begin
          pd_fsm_en_pulse_det_r[0] <= #TP 1'b0;
          int_prev_p1cpm_r <= #TP 1'b0;
        end
        if(int_prev_maxpclk_on_r) begin 
          pd_fsm_maxpclk_back_on <= #TP 1'b1;
          pd_fsm_maxpclk_removed <= #TP 1'b0;
        end
        int_prev_maxpclk_on_r <= #TP 1'b0;
      end
      ASYNC_HS_ENTER : begin
        pd_fsm_sel_aux_clk_r     <= #TP pd_fsm_sel_aux_clk_r;
        pd_fsm_pclkack_n_r <= #TP 1'b1;
        pd_fsm_asyncpowerchange_ack_r <= #TP 1'b1;
        pd_fsm_en_async_hs_r <= #TP 1'b1;
      end
      ASYNC_HS_EXIT : begin
        pd_fsm_sel_aux_clk_r     <= #TP pd_fsm_sel_aux_clk_r;
        pd_fsm_pclkack_n_r <= #TP 1'b1;
        pd_fsm_asyncpowerchange_ack_r <= #TP 1'b0;
        pd_fsm_en_async_hs_r <= #TP 1'b1;
        // P1.1 asynchronous handshake
        if(current_pwdw_p11) begin
          int_p1sub_hs_done_r <= #TP 1'b1;
        end
        // P1.2 asynchronous handshake
        else if(current_pwdw_p12) begin
          int_p1sub_hs_done_r <= #TP 1'b1;
          pd_fsm_pg_ack_r <= #TP 1'b1;
        end
      end
      PD_TPOWER_ON : begin
        pd_fsm_pclkreq_n_r <= #TP 1'b0;
        int_prev_p1sub_r <= #TP 1'b0;
        pd_fsm_en_pulse_det_r[0] <= #TP 1'b0;
      end
      MAXPCLK_OFF : begin
        mac_phy_maxpclkreq_n     <= #TP !pm_perst_powerdown; // Only request to remove maxpclk when !pm_perst_powerdown not happen
        pd_fsm_maxpclk_removed   <= #TP 1'b1;
        int_prev_maxpclk_off_r   <= #TP 1'b1;
        // Keep the value of the following signal
        int_lp_nego_r            <= #TP int_lp_nego_r;
        pd_fsm_pclkack_n_r       <= #TP pd_fsm_pclkack_n_r;
        pd_fsm_en_async_hs_r     <= #TP pd_fsm_en_async_hs_r;
        pd_fsm_sel_aux_clk_r     <= #TP pd_fsm_sel_aux_clk_r;
        if (pm_req_exit_p2) begin
          int_pm_req_exit_p2     <= #TP 1'b1;
        end
      end
      MAXPCLK_ON : begin
        mac_phy_maxpclkreq_n     <= #TP 1'b0;
        pd_fsm_maxpclk_removed   <= #TP pd_fsm_maxpclk_removed;
        int_prev_maxpclk_on_r    <= #TP 1'b1;
        // Keep the value of the following signal
        int_lp_nego_r            <= #TP int_lp_nego_r;
        pd_fsm_pclkack_n_r       <= #TP pd_fsm_pclkack_n_r;
        pd_fsm_en_async_hs_r     <= #TP pd_fsm_en_async_hs_r;
        // keep aux_clk on until maxpclk is back
        pd_fsm_sel_aux_clk_r <= #TP 1'b1;
        // ref clk needs to be on before aux clk switch.
        pd_fsm_pclkreq_n_r       <= #TP 1'b0;
        if (pm_req_exit_p2) begin
          int_pm_req_exit_p2     <= #TP 1'b1;
        end
      end
    endcase
    // if fundamental reset trigger PMA reset, drive P1
    if(pm_perst_powerdown) begin
      pd_fsm_powerdown_r            <= #TP P1;
    end
  end
end : pd_fsm_outputs_PROC

assign pd_fsm_powerdown_p1 = (pd_fsm_powerdown_r == P1);
// powerdown is P1CPM, P1_1 or P1_2, in which ref clk will be removed
assign pd_fsm_powerdown_no_clk = (pd_fsm_powerdown_r == P1CPM)
                                 || (pd_fsm_powerdown_r == P1_1) || (pd_fsm_powerdown_r == P1_2)
                                 ;


endmodule
