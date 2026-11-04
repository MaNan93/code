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
// ---    $Revision: #18 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_ctrl_l1sub.sv#18 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module provides the additional L1 substates and the associated
// --- PIPE level signaling with the PHY.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_active_ctrl_l1sub
#(
    parameter INST = 0,
    parameter PM_CPL_TIMER_WD = 1,
    parameter L1SUB_CONTROL_WD = 1,
    parameter PL_L1SUB_CONTROL_WD = 1,
    parameter PM_SYNC_DEPTH = 2
)
(
// ---- inputs ---------------
    input                             aux_clk,
    input                             aux_clk_en_1us,  // clock enable to mark 1us time intervals
    input                             pwr_rst_n,
    input                             next_pm_state_is_l1, // active when on next cycle USP LINK FSM == L1 or DSP LINK FSM == L1
    input                             smlh_in_l0, // LTSSM is in L0, used for remotely initiated L1 exit
    input                             latch_int_l1_exit, // internal L1 exit, used for locally initiated L1 exit
    input                             phy_link_up, // used to reset state machine
    input                             aux_clk_active, // muxed aux clk has switched to low frequency clock, used when entering L1 to stall progression into L1 substates
    input                             aux_clk_inactive, // muxed aux clk has switched to core clock
    input                             phy_mac_pclkack_n, // PCLK removal request acknowledge, 1: PCLK is removed, PHY is ready for REFCLK removal, 0: PCLK is active
    input                             pm_clkreq_in_n, // the state of the CLKREQ# pin on the connector, used for remotely initiated exit from L1 substates
    input [L1SUB_CONTROL_WD-1:0]      cfg_l1sub_control, // L1 substates control signal bus from cdm_l1sub_reg
    input [PL_L1SUB_CONTROL_WD-1:0]   cfg_pl_l1sub_control, // L1 Substates control signal bus from cdm_pl_reg
    input                             cfg_trgt_l1cpm,    // target L1 according to Clock PM control mechanism: binary encoding: 0 = L1 without CLKREQ#=1, 1 = L1 with CLKREQ#=1                      
    input                             gasket_powerdown_p1_2,
    input                             aspm_l1_entry, // L1 entry due to ASPM
    input                             pcipm_l1_entry, // L1 entry due to PCIPM
    input                             app_l1sub_disable, // Gate the L1 sub-states enable bits
    input                             gasket_maxpclk_removed, // Indicate the maxpclk is removed
    input                             pm_req_non_sticky_rst, 
    input                             pm_l1sub_fsm_rst,
    input                             cxl_link_enable,
    input                             smlh_cal_req,
// ---- outputs ---------------
    output reg [1:0]                  cfg_trgt_l1sub,    // target L1 according to L1 substates control mechanism: binary encoding: 0-1-2 for L1.0-1-2 respectively
    output                            l1sub_l11_next,    // target L1.1
    output                            l1sub_l12_next,    // target L1.2
    output                            l1sub_abort_next,  // L1.2 entry aborted
    output                            l1sub_req_p1cpm,   // Request P1.CPM transition on powerdown 
    output reg [1:0]                  mac_phy_pclkreq_n, // Request PCLK removal:
                                                         // 2'b00: do not request PCLK removal
                                                         // 2'b01: request PCLK removal for executing L1 with Clock PM
                                                         // 2'b10: request PCLK removal for executing L1 substates
                                                         // 2'b11: request PCLK removal for executing L1 substates with Clock PM
    output reg                        mac_phy_rxelecidle_disable, // disable rx electrical idle detection circuits
    output reg                        mac_phy_txcommonmode_disable, // disable tx common mode circuits
    output reg                        l1sub_smlh_l1_2_latched, // l1sub in L1.2, cleared when LTSSM in L0
    output reg                        l1sub_smlh_l1_n_latched, // l1sub in L1.N, cleared when LTSSM in L0
    output                            l1sub_state_is_l1_u, // it is used by USP LINK FSM or DSP LINK FSM to exit L1
    output                            l1sub_pg_enable, // used to enable power gating in L1.2
    output                            l1sub_pg_disable, // used to disable power gating in L1.2
    output reg [2:0]                  l1sub_state
   ,output reg                        pm_in_l11,
    output reg                        pm_in_l12,
    output reg                        pm_in_l1_short,
    output reg                        pm_in_l1_cpm,
    output reg                        pm_in_l1_abort
    ,
    output                            l1sub_clk_req_n, // clkreq output of the controller in l1 sub-states 
    output reg                        l1sub_sel_aux_clk // request to clock and reset to switch the source of aux_clk
    ,
    output                            pm_pclkack_timeout // t_pclkack timeout will trigger internal fatal error
    ,
    output logic                      ltssm_track_l1sub_exit
);

parameter TP                    = `TP; // Clock to Q delay (simulator insurance) - parameter instead of localparam to workaround leda warning 129
localparam US_TIMER_WD          = log2roundup(100*31); // = 12 bits, use function for readability only, number of bits to count worst case which is t_power_on_value = 31 with a scale of 100us
// fsm states
localparam [2:0] S_L1_U               = 3'h0; // idle state
localparam [2:0] S_L1_0               = 3'h1; // wait for aux_clk_active
localparam [2:0] S_L1_0_WAIT4_ACK     = 3'h2; // wait for pclkack
localparam [2:0] S_L1_0_WAIT4_CLKREQ  = 3'h3; // wait for clkreq
localparam [2:0] S_L1_N_ENTRY         = 3'h4; // check clkreq_in_n is de-asserted for t_power_off time (only for L1.2, reduces to one cycle for L1.1)
localparam [2:0] S_L1_N               = 3'h5; // L1 substate, turn off txcommonmode circuits (L1.2 only) and rx electrical idle detection circuits
localparam [2:0] S_L1_N_EXIT          = 3'h6; // locally/remotely initiated exit, assert pclkreq, wait for pclkack
localparam [2:0] S_L1_N_ABORT         = 3'h7; // wait for pclkack when aborting an attempt to enter L1_N

// internal
reg [US_TIMER_WD-1:0] us_timer; // microsecond timer
reg [2:0] next_l1sub_state;
reg   int_clk_req_n_r;
wire  int_clk_req_n_s;
wire  int_deassert_clk_req_s;
wire l1sub_exit;
wire clear;
reg timeout_t_pclkack, timeout_t_power_off, timeout_t_l1_2, timeout_t_power_on;
reg        cfg_trgt_l1cpm_latched;
wire [11:0] cfg_l1sub_t_power_on; // power on time in us
wire [1:0] cfg_pl_l1sub_t_power_off; // Duration (in 1us unit) of L1.2 Entry
wire [3:0] cfg_pl_l1sub_t_l1_2; // Duration (in 1us unit) of L1.2
wire [6:0] cfg_pl_l1sub_t_pclkack; // Max delay (in 1us unit) between a MAC command on mac_phy_pclkreq_n and a PHY response on phy_mac_pclkack_n
wire        int_fast_exit_mode; // enable fast exit mode for a DSP
wire        int_normal_mode; // perform the normal transitions to get to L1.N.Entry
reg         int_clkreq_detected_r; // clreq was asserted in L1_N so prevent subsequent L1 sub-states entry until exit from L1 completes



wire [1:0]  cfg_trgt_pcipm_l1sub;
wire [1:0]  cfg_trgt_aspm_l1sub;
wire [1:0]  int_cfg_trgt_pcipm_l1sub;
wire [1:0]  int_cfg_trgt_aspm_l1sub;

assign int_cfg_trgt_pcipm_l1sub[1:0] = cxl_link_enable ? 2'b0 : cfg_l1sub_control[`CX_L1SUB_CONTROL_PCIPM_TRGT_L1SUB_RANGE];
assign int_cfg_trgt_aspm_l1sub[1:0] = cxl_link_enable ? 2'b0 : cfg_l1sub_control[`CX_L1SUB_CONTROL_ASPM_TRGT_L1SUB_RANGE];

assign cfg_trgt_pcipm_l1sub[1:0] = {2{!app_l1sub_disable}} & int_cfg_trgt_pcipm_l1sub;
assign cfg_trgt_aspm_l1sub[1:0] = {2{!app_l1sub_disable}} & int_cfg_trgt_aspm_l1sub;

always @(*) begin : trgt_l1sub_PROC
  cfg_trgt_l1sub = 0;
  if(pcipm_l1_entry) begin
    if(cfg_trgt_pcipm_l1sub[1])
      cfg_trgt_l1sub = 2;
    else if(cfg_trgt_pcipm_l1sub[0])
      cfg_trgt_l1sub = 1;
  end else if(aspm_l1_entry) begin
    if(cfg_trgt_aspm_l1sub[1])
      cfg_trgt_l1sub = 2;
    else if(cfg_trgt_aspm_l1sub[0])
      cfg_trgt_l1sub = 1;
  end
end : trgt_l1sub_PROC

// latch cfg_trgt_l1cpm any time L1_U is exited, to ensure a stable value is kept throughout for driving correctly pclkreq_n[0], regardless of the changes on app_clk_pm_en
// no need to latch cfg_trgt_l1sub because we don't expect this to change while doing L1 (substates must be managed consistently on boths sides of the link by system software)
always @(posedge aux_clk or negedge pwr_rst_n) begin : cfg_trgt_l1cpm_seq_PROC
    if (!pwr_rst_n) begin
        cfg_trgt_l1cpm_latched <= #TP 0;
    end else begin
        if ( (l1sub_state==S_L1_U) && (next_l1sub_state != l1sub_state)|| pm_req_non_sticky_rst ) begin
            cfg_trgt_l1cpm_latched <= #TP cfg_trgt_l1cpm;
        end
    end
end

assign cfg_l1sub_t_power_on[11:0] = cfg_l1sub_control[`CX_L1SUB_CONTROL_T_POWER_ON_RANGE];

assign {cfg_pl_l1sub_fast_exit, cfg_pl_l1sub_t_pclkack, cfg_pl_l1sub_t_l1_2, cfg_pl_l1sub_t_power_off} = cfg_pl_l1sub_control;

always @(posedge aux_clk or negedge pwr_rst_n) begin : us_timer_PROC
    if (!pwr_rst_n) begin
        us_timer <= #TP 0;
    end else if (clear) begin
        us_timer <= #TP 0;
    end else if( aux_clk_en_1us ) begin
        us_timer <= #TP us_timer + 1'b1; // free running is ok provided the timeout flags are sticky, i.e. don't get reset after the timer rolls over
    end
end

// fsm inputs
always @(posedge aux_clk or negedge pwr_rst_n) begin : timeout_PROC
    if (!pwr_rst_n) begin
        timeout_t_pclkack   <= #TP 1'b0;
        timeout_t_power_off <= #TP 1'b0;
        timeout_t_power_on  <= #TP 1'b0;
        timeout_t_l1_2      <= #TP 1'b0;
    end else if (clear) begin
        timeout_t_pclkack   <= #TP 1'b0;
        timeout_t_power_off <= #TP (cfg_trgt_l1sub == 2) ? 1'b0 : 1'b1; // pretend timers are all expired if target is not L1.2, so state machine does not wait when not necessary
        timeout_t_power_on  <= #TP (cfg_trgt_l1sub == 2) ? 1'b0 : 1'b1;
        timeout_t_l1_2      <= #TP (cfg_trgt_l1sub == 2) ? 1'b0 : 1'b1;
    end else begin
        if( aux_clk_en_1us ) begin // wait next 1us clock enable to compensate for the initial us_timer increment which may be shorter than 1us
            if ((us_timer == {{(US_TIMER_WD - 7){1'b0}}, cfg_pl_l1sub_t_pclkack}) && cfg_pl_l1sub_t_pclkack!=0)    timeout_t_pclkack   <= #TP 1'b1;
            if (us_timer == {{(US_TIMER_WD - 2){1'b0}}, cfg_pl_l1sub_t_power_off})  timeout_t_power_off <= #TP 1'b1;
            if (us_timer == {{(US_TIMER_WD - 4){1'b0}}, cfg_pl_l1sub_t_l1_2})       timeout_t_l1_2      <= #TP 1'b1;
            if (us_timer == cfg_l1sub_t_power_on)                                   timeout_t_power_on  <= #TP 1'b1;
        end
    end
end

assign l1sub_exit = (smlh_in_l0 || latch_int_l1_exit || (!phy_link_up));
assign int_fast_exit_mode = cfg_pl_l1sub_fast_exit && ((cfg_trgt_l1sub != 0));
assign int_normal_mode = ((cfg_trgt_l1sub != 0) || (cfg_trgt_l1cpm != 0));
// Only when pclkreq is asserted and wait for paclkack, the t_pclkack timeout will trigger internal error.
assign pm_pclkack_timeout = timeout_t_pclkack && |(mac_phy_pclkreq_n) && !phy_mac_pclkack_n;

assign ltssm_track_l1sub_exit = l1sub_exit || !pm_clkreq_in_n;


// fsm state
always @(*) begin : next_l1sub_state_PROC
    next_l1sub_state = l1sub_state;
    case (l1sub_state)
        S_L1_0 : begin
            if( l1sub_exit ) begin
                next_l1sub_state = S_L1_U;
            end else if( aux_clk_active ) begin
                next_l1sub_state = S_L1_0_WAIT4_ACK;
            end
        end
        S_L1_0_WAIT4_ACK : begin
            if( l1sub_exit && timeout_t_pclkack ) begin // while in this state l1sub_exit is not served (unless there is a timeout) because we are committed to wait for pclkack
                next_l1sub_state = S_L1_U;
            end else if( phy_mac_pclkack_n ) begin
                if( cfg_trgt_l1sub == 0 && cfg_trgt_l1cpm_latched != 0 ) begin // do standard L1 (not the substates) with CLKREQ#=1
                    next_l1sub_state = S_L1_N;
                end else begin // do L1 substates
                    next_l1sub_state = S_L1_0_WAIT4_CLKREQ;
                end
            end
        end
        S_L1_0_WAIT4_CLKREQ : begin
            // In fast exit mode move directly back to S_L1_U CLKREQ# is not asserted and the clock switch is not performed
            if( l1sub_exit && int_fast_exit_mode ) begin
                next_l1sub_state = S_L1_U;
            // Normally we go to the ABORT state to request PCLK to be re-enabled before returning to the IDLE state
            end else if( l1sub_exit ) begin
                next_l1sub_state = S_L1_N_ABORT;
            // CLKREQ# de-asserted proceed to S_L1_N_ENTRY
            end else if( pm_clkreq_in_n ) begin
                next_l1sub_state = S_L1_N_ENTRY;
            end
        end
        S_L1_N_ENTRY : begin
            // Tpower_off expired proceed to L1 sub-state
            if( timeout_t_power_off ) begin
              // In fast exit mode wait for the clock switch to complete before proceeding to L1 sub-state
              if( int_fast_exit_mode ) begin
                if( aux_clk_active && phy_mac_pclkack_n ) begin
                  next_l1sub_state = S_L1_N;
                end else begin
                  next_l1sub_state = S_L1_N_ENTRY;
                end
              end else begin
                next_l1sub_state = S_L1_N;
              end
            // CLKREQ# is asserted so abort entry to L1 sub-states
            end else if( !pm_clkreq_in_n ) begin
              // Normally transition immediately back to S_L1_0_WAIT4_CLKREQ since the PCLKACK handshake has already happened
              if ( !int_fast_exit_mode )
                next_l1sub_state = S_L1_0_WAIT4_CLKREQ;
              // In fast exit mode wait for PCLKACK to be set to 1'b1 before exiting
              else if ( phy_mac_pclkack_n )
                next_l1sub_state = S_L1_0_WAIT4_CLKREQ;
              else
                next_l1sub_state = S_L1_N_ENTRY;
            end
        end
        S_L1_N : begin
            // Local exit applies to both sub-states and CPM 
            if( l1sub_exit && timeout_t_l1_2 ) begin
                if( !int_fast_exit_mode )
                  next_l1sub_state = S_L1_N_EXIT;
                // In fast exit mode wait for pclkack_n to be asserted
                else if ( phy_mac_pclkack_n )
                  next_l1sub_state = S_L1_N_EXIT;
                else
                  next_l1sub_state = S_L1_N;
            // this arc depends on clkreq_in_n, therefore does not apply to Clock PM
            end else if( (cfg_trgt_l1sub != 0) && !pm_clkreq_in_n && timeout_t_l1_2 ) begin
                if( !int_fast_exit_mode )
                  next_l1sub_state = S_L1_N_EXIT;
                // In fast exit mode wait for pclkack_n to be asserted
                else if ( phy_mac_pclkack_n )
                  next_l1sub_state = S_L1_N_EXIT;
                else
                  next_l1sub_state = S_L1_N;
            end
        end
        S_L1_N_EXIT : begin
            if( timeout_t_power_on & !gasket_maxpclk_removed & aux_clk_inactive) begin
                next_l1sub_state = S_L1_U;
            end
        end
        S_L1_N_ABORT : begin
            if( (!phy_mac_pclkack_n || timeout_t_pclkack) ) begin
                next_l1sub_state = S_L1_U;
            end else begin
                next_l1sub_state = l1sub_state;
            end
        end
        default /* S_L1_U */ : begin
            if( int_fast_exit_mode && next_pm_state_is_l1 && !int_clkreq_detected_r
 && !cxl_link_enable && !smlh_cal_req)
            begin
                next_l1sub_state = S_L1_0_WAIT4_CLKREQ;
            end else if ( int_normal_mode && next_pm_state_is_l1 && !int_clkreq_detected_r
 && !cxl_link_enable && !smlh_cal_req)
            begin
                next_l1sub_state = S_L1_0;
            end else begin
                next_l1sub_state = S_L1_U;
            end
        end
    endcase
end

always @(posedge aux_clk or negedge pwr_rst_n) begin : det_clkreq_proc
  if (!pwr_rst_n) begin
    int_clkreq_detected_r <= #TP 1'b0;
  end else begin
    if (!pm_clkreq_in_n && (l1sub_state == S_L1_N)) begin
      int_clkreq_detected_r <= #TP 1'b1;
    end else if (!next_pm_state_is_l1) begin
      int_clkreq_detected_r <= #TP 1'b0;
    end else begin
      int_clkreq_detected_r <= #TP int_clkreq_detected_r;
    end
  end
end : det_clkreq_proc

// Signals to power management unit to power up or down the circuitry in L1.2
assign l1sub_pg_enable = (l1sub_state == S_L1_N) && !l1sub_exit && (cfg_trgt_l1sub == 2) && pm_clkreq_in_n;
assign l1sub_pg_disable = (l1sub_state == S_L1_N_EXIT);
assign l1sub_l11_next = (l1sub_state == S_L1_N) && (cfg_trgt_l1sub ==  2'b01);
assign l1sub_l12_next = (l1sub_state == S_L1_N) && (cfg_trgt_l1sub ==  2'b10);
assign l1sub_abort_next = (next_l1sub_state == S_L1_N_ABORT);
assign l1sub_req_p1cpm = (next_l1sub_state == S_L1_0) || (next_l1sub_state == S_L1_N_ENTRY);

always @(posedge aux_clk or negedge pwr_rst_n) begin : l1sub_state_PROC
    if (!pwr_rst_n) begin
        l1sub_state <= #TP S_L1_U;
    end else if (pm_l1sub_fsm_rst) begin
        // when pma or phy reset (due to perst_n) reset L1SUB FSM
        l1sub_state <= #TP S_L1_U;
    end else begin
        l1sub_state <= #TP next_l1sub_state;
    end
end

assign clear = (next_l1sub_state != l1sub_state)
               || (gasket_powerdown_p1_2 && (l1sub_state == S_L1_N_EXIT))
               ;

// CLKREQ# must be de-asserted later in the entry process if the fast exit mode is being used
assign int_deassert_clk_req_s = ((l1sub_state == S_L1_0_WAIT4_CLKREQ) || (l1sub_state == S_L1_N_ENTRY) || (l1sub_state == S_L1_N));
assign int_clk_req_n_s = int_fast_exit_mode ? int_deassert_clk_req_s : 1'b0;
// In fast exit mode CLKREQ# signallining is seperate from the mac_phy_pclkreq_n signal, otherwise it is the same signal
assign l1sub_clk_req_n = int_fast_exit_mode ? int_clk_req_n_r : |(mac_phy_pclkreq_n);

// fsm outputs
always @(posedge aux_clk or negedge pwr_rst_n) begin : output_seq_PROC
    if (!pwr_rst_n) begin
        mac_phy_pclkreq_n <= #TP 0;
        mac_phy_rxelecidle_disable <= #TP 0;
        mac_phy_txcommonmode_disable <= #TP 0;
        int_clk_req_n_r <= #TP 1'b0;
        l1sub_sel_aux_clk <= #TP 1'b0;
    end else begin
        int_clk_req_n_r <= #TP int_clk_req_n_s;

        // Control of the aux_clk switch in fast exit mode only set when we enter L1.N.Entry
        if( int_fast_exit_mode ) begin
          l1sub_sel_aux_clk <= #TP ((next_l1sub_state == S_L1_N_ENTRY) ? 1'b1 :
 (next_l1sub_state == S_L1_N_EXIT) ? 1'b0 :
                                    (next_l1sub_state == S_L1_U) ? 1'b0 :
                                    l1sub_sel_aux_clk);
        // Otherwise switch the clock on entry to L1.0 
        end else begin
          l1sub_sel_aux_clk <= #TP ((next_l1sub_state == S_L1_0) ? 1'b1 :
  (next_l1sub_state == S_L1_N_EXIT) ? 1'b0 :
                                    ((next_l1sub_state == S_L1_U) ? 1'b0 :
                                    l1sub_sel_aux_clk));
        end

        if( cfg_trgt_l1sub != 0 ) begin // behavior when the substates are enabled
            if( int_fast_exit_mode ) begin
              mac_phy_pclkreq_n[1] <= #TP (l1sub_state == S_L1_N_ENTRY) ? 1'b1 :
                                       ((l1sub_state == S_L1_N_EXIT) || (l1sub_state == S_L1_0_WAIT4_CLKREQ) || (l1sub_state == S_L1_U)) ? 1'b0 :
                                       mac_phy_pclkreq_n[1];
            end else begin
              mac_phy_pclkreq_n[1] <= #TP (l1sub_state==S_L1_0_WAIT4_ACK) ? 1 : // set
                                       ((l1sub_state==S_L1_N_EXIT)||(l1sub_state==S_L1_N_ABORT)||(l1sub_state==S_L1_U)) ? 0 : // reset
                                       mac_phy_pclkreq_n[1]; // hold
            end
            mac_phy_rxelecidle_disable <= #TP (l1sub_state==S_L1_N);
            mac_phy_txcommonmode_disable <= #TP (l1sub_state==S_L1_N) && (cfg_trgt_l1sub == 2);
        end else begin // behavior when the substates are disabled
            mac_phy_pclkreq_n[1] <= #TP 0;
            mac_phy_rxelecidle_disable <= #TP 0;
            mac_phy_txcommonmode_disable <= #TP 0;
        end
        if( cfg_trgt_l1cpm_latched == 1'b1 ) begin // behavior when the Clock PM is enabled
            if( int_fast_exit_mode ) begin
              mac_phy_pclkreq_n[0] <= #TP (l1sub_state == S_L1_N_ENTRY) ? 1'b1 :
                                       ((l1sub_state == S_L1_N_EXIT) || (l1sub_state == S_L1_0_WAIT4_CLKREQ) || (l1sub_state == S_L1_U)) ? 1'b0 :
                                       mac_phy_pclkreq_n[0];
            end else begin
              mac_phy_pclkreq_n[0] <= #TP (l1sub_state==S_L1_0_WAIT4_ACK) ? 1 : // set
                                       ((l1sub_state==S_L1_N_EXIT)||(l1sub_state==S_L1_N_ABORT)||(l1sub_state==S_L1_U)) ? 0 : // reset
                                       mac_phy_pclkreq_n[0]; // hold
            end
        end else begin // behavior when Clock PM is disabled
            mac_phy_pclkreq_n[0] <= #TP 0;
        end
    end
end

//latch entry to L1_2 and clear it when in L0 or not in linkup.
//used for LTSSM to wait for Tcommon_mode time to transition to Recovery.RcvrCfg from Recovery.RcvrLock.
always @( posedge aux_clk or negedge pwr_rst_n ) begin : l1sub_smlh_l1_2_latched_PROC
    if ( !pwr_rst_n ) begin
        l1sub_smlh_l1_2_latched <= #TP 0;
    end else begin
        if ( ~phy_link_up || smlh_in_l0 ) begin
            l1sub_smlh_l1_2_latched <= #TP 0;
        end else if ( (l1sub_state==S_L1_N) && (cfg_trgt_l1sub == 2) ) begin
            l1sub_smlh_l1_2_latched <= #TP 1;
        end
    end
end //l1sub_smlh_l1_2_latched_PROC

//latch entry to L1_N and clear it when in L0 or not in linkup.
//used for LTSSM to exit L1.Idle -> Recovery for timeout_40ns condition because of core_clk off (timer is stuck in LTSSM)
always @( posedge aux_clk or negedge pwr_rst_n ) begin : l1sub_smlh_l1_n_latched_PROC
    if ( !pwr_rst_n ) begin
        l1sub_smlh_l1_n_latched <= #TP 0;
    end else begin
        if ( ~phy_link_up || smlh_in_l0 ) begin
            l1sub_smlh_l1_n_latched <= #TP 0;
        end else if ( l1sub_state==S_L1_N ) begin
            l1sub_smlh_l1_n_latched <= #TP 1;
        end
    end
end //l1sub_smlh_l1_n_latched_PROC

assign l1sub_state_is_l1_u = (next_l1sub_state==S_L1_U);

function automatic integer log2roundup(input integer value);
    begin
        log2roundup = 1;
        // LMD: Illegal statement for synthesis
        // LJ: Triggers Bogus Leda Error. This func is only used in parameter calculation.
        // leda W182 off
        while(1<<log2roundup <= value)
        // leda W182 on
            log2roundup = log2roundup + 1;


    end
endfunction

`ifndef SYNTHESIS
wire  [21*8:0]  L1SUB_STATE;
assign  L1SUB_STATE = (l1sub_state == S_L1_U               ) ? "L1_U" :
                      (l1sub_state == S_L1_0               ) ? "L1_0":
                      (l1sub_state == S_L1_0_WAIT4_ACK     ) ? "L1_0_WAIT4_ACK":
                      (l1sub_state == S_L1_0_WAIT4_CLKREQ  ) ? "L1_0_WAIT4_CLKREQ":
                      (l1sub_state == S_L1_N_ENTRY         ) ? "L1_N_ENTRY":
                      (l1sub_state == S_L1_N               ) ? "L1_N":
                      (l1sub_state == S_L1_N_EXIT          ) ? "L1_N_EXIT":
                      (l1sub_state == S_L1_N_ABORT         ) ? "L1_N_ABORT":
                                                               "UNKNOWN";
`endif // !SYNTHESIS

//L1.1 Entry
//L1.2 Entry
always @(posedge aux_clk or negedge pwr_rst_n) begin : pm_in_l1sub_PROC
    if (!pwr_rst_n) begin
        pm_in_l11 <= #TP 0;
        pm_in_l12 <= #TP 0;
    end else if ( l1sub_state==S_L1_N ) begin
        if ( cfg_trgt_l1sub==1 )
            pm_in_l11 <= #TP 1;

        if ( cfg_trgt_l1sub==2 )
            pm_in_l12 <= #TP 1;
    end else begin
        pm_in_l11 <= #TP 0;
        pm_in_l12 <= #TP 0;
    end
end        

//L1 Clock PM
//(L1 with REFCLK removal/PLL Off)
always @(posedge aux_clk or negedge pwr_rst_n) begin : pm_in_l1_cpm_PROC
    if (!pwr_rst_n) 
        pm_in_l1_cpm <= #TP 0;
    else
        pm_in_l1_cpm <= #TP mac_phy_pclkreq_n[0];
end

//L1 short duration
//L1.2 abort
reg pm_l1_n_entry_latched;

always @(posedge aux_clk or negedge pwr_rst_n) begin : pm_in_l1_abort_PROC
    if (!pwr_rst_n) begin
        pm_in_l1_abort <= #TP 0;
        pm_in_l1_short <= #TP 0;
        pm_l1_n_entry_latched <= #TP 0;
    end else begin
        // l1 short : not entered S_L1_N_ENTRY
        // l1 abort : once entered S_L1_N_ENTRY but consequently entered S_L1_N_ABORT
        if (l1sub_state==S_L1_U) begin
            pm_l1_n_entry_latched <= #TP 0;
        end else if (l1sub_state==S_L1_N_ENTRY) begin
            pm_l1_n_entry_latched <= #TP 1;
        end

        if(next_l1sub_state==S_L1_U && l1sub_state!=S_L1_U && ~pm_l1_n_entry_latched) begin
            pm_in_l1_short <= #TP 1;
        end else begin
            pm_in_l1_short <= #TP 0;
        end

        if (next_l1sub_state==S_L1_N_ABORT && pm_l1_n_entry_latched) begin
            pm_in_l1_abort <= #TP 1;
        end else begin
            pm_in_l1_abort <= #TP 0;
        end
    end
end


endmodule // pm_active_ctrl_l1sub
