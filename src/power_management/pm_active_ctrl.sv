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
// ---    $DateTime: 2024/01/12 13:55:57 $
// ---    $Revision: #47 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_ctrl.sv#47 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module provides control logic for Active State PM as well as
// --- dllp pm control
// --- It has the following job to complete:
// --- 1. reponsible to control the entry of L0s as specified in active state
// --- power management spec.
// --- 2. reponsible to control the entry of L1 as specified in active state
// --- power management spec.
// --- 3. reponsible to control the entry of L2 or 3 as PCI_PM specification,
// --- before power can be removed, a l23 ready dllp has to be sent and
// --- transition the same way as L1.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
 
module pm_active_ctrl 
  import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
  import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
  import DWC_pcie_pm_pkg::DSP_LINK_L23RDY;
  import DWC_pcie_pm_pkg::DSP_LINK_L23RDY_WAIT4ALIVE;
  import DWC_pcie_pm_pkg::DSP_LINK_L1;
  import DWC_pcie_pm_pkg::DSP_LINK_L1_EXIT;
  import DWC_pcie_pm_pkg::DSP_LINK_L0;
  import DWC_pcie_pm_pkg::DSP_LINK_RST;
  import DWC_pcie_pm_pkg::USP_LINK_L1_LINK_ENTR_L1;
  import DWC_pcie_pm_pkg::USP_LINK_L1;
  import DWC_pcie_pm_pkg::USP_LINK_L1_EXIT;
  import DWC_pcie_pm_pkg::USP_LINK_L23RDY;
  import DWC_pcie_pm_pkg::USP_LINK_L23RDY_WAIT4ALIVE;
  import DWC_pcie_pm_pkg::USP_LINK_RST;
  import DWC_pcie_pm_pkg::USP_LINK_RECOVERY;
  import DWC_pcie_pm_pkg::USP_LINK_L0;
// Parameters
#(
  parameter INST                      = 0,                    // The uniquifying parameter for each port logic instance.
  parameter PM_SYNC_DEPTH             = 2,
  parameter L1SUB_CONTROL_WD          = 1,
  parameter PL_L1SUB_CONTROL_WD       = 1,
  parameter PM_CPL_TIMER_WD           = 1,
  parameter NL                        = `CX_NL,
  parameter NF                        = `CX_NFUNC,            // number of functions
  parameter NVC                       = `CX_NVC,              // number of VCs
  parameter PD_WIDTH                  = 2,
  parameter PHY_NB                    = `CX_PHY_NB,
  parameter PHY_TXEI_WD               = `CX_PHY_TXEI_WD,
  parameter P0                        = {PD_WIDTH{1'b0}},
  parameter P1                        = {PD_WIDTH{1'b0}},
  parameter P2                        = {PD_WIDTH{1'b0}},
  parameter PL_AUX_CLK_FREQ_WD        = 1,
  parameter TP                        = `TP                   // Clock to Q delay (simulator insurance)
) 
                       (
  //------------------------------------------------------------------------------
  // Clock&Reset
  //------------------------------------------------------------------------------
  input                                 aux_clk,                      // Auxiliary clock
  input                                 pwr_rst_n,                    // Power-On reset
  input                                 perst_n,                      // Main power removal indication
  input                                 perst_n_posedge,              // perst_n posedge
  //------------------------------------------------------------------------------
  // Configuration Interface
  //------------------------------------------------------------------------------
  input                                 switch_device,                // CFG: 1 indicate that it is a switch device; 0 indicate that it is a EP/RC/bridge device
  input                                 upstream_port,                // CFG: 1 indicate that it is an upstream port (EP/upstream port of a SW)
  input  [PL_AUX_CLK_FREQ_WD-1:0]       pm_pl_aux_clk_freq,           // CDM: Programmable auxiliary clock frequency
  input                                 pl_l1_clk_sel,                // CDM: Port Logic bit which disables clock switching in L1
  input                                 pm_clk_pm_en,                 // CDM: Clock PM feature enabled by software
  input                                 pm_pl_gen3_zrxdc_noncompl,    // CDM: Gen3 Zrx-dc noncompliance bit (8 GT/s Rx Impedance ECN).
  input  [L1SUB_CONTROL_WD-1:0]         pm_l1sub_control,             // CDM: L1 substates control signal bus from cdm_l1sub_reg
  input  [PL_L1SUB_CONTROL_WD-1:0]      pm_pl_l1sub_control,          // CDM: L1 Substates control signal bus from cdm_pl_reg
  input                                 pm_pl_l1_exit_mode,           // CDM: Port logic bit to control L1 exit mode
  input  [PD_WIDTH-1:0]                 pm_cfg_phy_powerdown_p2_options, // CDM: Drive P2 or P2.NoBeacon
  output logic                          pm_linkst_in_l0,              // CDM: Power management is in L0 state
  output logic [2:0]                    l1sub_state,                  // CDM: Power management L1 sub-states FSM state
  output logic                          pm_pclkack_timeout,           // CDM: 
  output logic                          pm_in_l11,                    // CDM: L1.1 Entry
  output logic                          pm_in_l12,                    // CDM: L1.2 Entry
  output logic                          pm_in_l1_short,               // CDM: L1 short duration
  output logic                          pm_in_l1_cpm,                 // CDM: L1 Clock PM (L1 with REFCLK removal/PLL Off)
  output logic                          pm_in_l1_abort,               // CDM: L1.2 abort
  output logic [(PD_WIDTH - 1) : 0]     pm_int_phy_powerdown,         // CDM: PM to PHY power down
  //------------------------------------------------------------------------------
  // Application and PIPE Interfaces
  //------------------------------------------------------------------------------
  input  [NL-1:0]                       phy_mac_rxelecidle,           // PIPE: Indicates receiver detection of an Electrical Idle for each lane.
  input                                 phy_mac_pclkack_n,            // PIPE: PCLK removal request acknowledge, 1: PCLK is removed, PHY is ready for REFCLK removal, 0: PCLK is active
  output logic [NL*PHY_TXEI_WD-1:0]     pm_phy_txelecidle,            // PIPE: Forces transmit output to Electrical Idle for each lane which it is asserted
  input                                 aux_pm_det,                   // Application: AUX Power is detected
  input                                 app_clk_req_n,                // APM: Application request ref clock removal
  input                                 phy_clk_req_n,                // APM: PHY acknowledge that it is ready for ref clock removal
  input                                 app_l1sub_disable,            // Application: Gates the L1 sub-state enable bits from the L1 PM Substates Control 1 Register.
  output logic [2:0]                    pm_curnt_state,               // TOBEREMOVED: Application: PM current state
  output logic                          wake,                         // APM: The controller generates wake to request the system to restore power and clock when a wakeup event has been detected
  output logic                          local_ref_clk_req_n,          // APM: This signal may be connected to the CLKREQ# driver to negotiate entry into L1 sub-states.
                                                                      // For USP this signal is also used to request reference clock removal when CPM is enable
  output logic                          pm_linkst_in_l1,              // Application/PMU/Gasket: Power management is in L1 state
  output logic                          pm_linkst_in_l2,              // Application: Power management is in L2 state
  output logic                          pm_linkst_l2_exit,            // Application: Power management is exiting L2 state
  output logic                          pm_linkst_in_l3,              // Application: Power management is in L3 state
  output logic                          pm_linkst_in_l1sub,           // Application: Power management is in L1 substate.
  //------------------------------------------------------------------------------
  // CX_LOG_PHY: Physical Layer Interface
  //------------------------------------------------------------------------------
  input                                 pm_cxl_mode_enable,           // SPLH: Protocol Configuration CXL Mode Enablie bit
  input                                 phy_link_up,                  // SMLH: LTSSM is in link up
  input                                 smlh_in_l0,                   // SMLH: LTSSM is in L0
  input                                 smlh_in_l23,                  // SMLH: LTSSM is in L23
  input                                 smlh_cal_req,                 // SMLH: LTSSM CCIX calibrarion request signal to PHY
  input                                 link_req_rst_not,             // SMLH: LTSSM sets this signal to 0 to request a reset due to surprise link down
  input  usp_link_fsm_state_e           pm_usp_link_state,            // SMLH: PM Link FSM connections with PM Active Controller
  input  dsp_link_fsm_state_e           pm_dsp_link_state,            // SMLH: PM Link FSM connections with PM Active Controller
  output logic                          pm_hold_exit_l1,              // SMLH: PM Link FSM: Hold exit from L1
  output logic                          pm_link_exit_l1,              // SMLH: PM Link FSM/PM Wake: Request to exit from L1. Connection to PM Wake creates ARCH CONFLICT!!!!!!!!!!!
  output logic                          pm_link_exit_l23,             // SMLH: PM Link FSM: Request to exit from L23
  output logic                          pm_smlh_l1_2_latched,         // SMLH: LTSSM L1_SUB entered L1_2 substate
  output logic                          pm_smlh_l1_n_latched,         // SMLH: LTSSM L1_SUB entered L1_N substate
  input  [(PD_WIDTH - 1) : 0]           pre_pm_phy_powerdown,         // XMLH: Powerdown to PIPE phy. We intercept to drive P2
  input  [2:0]                          current_data_rate,            // RMLH: 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4
  //------------------------------------------------------------------------------
  // PM Controller Internal Connections
  //------------------------------------------------------------------------------
  input                                 pm_wakeup_event,              // PM Link Controller: Wakeup event
  output logic                          pm_phyinl1,                   // PM Link Controller: PM is in L1 and current power down state is P1
  output logic                          pm_phyinl2,                   // PM Link Controller: PM is in L2 and current power down state is P2
  output logic                          pm_en_core_clk_gating,        // PM Link Controller: Enable core_clk gating
  input                                 aux_clk_active,               // PM Clock Controller: muxed aux clk has switched to low frequency clock, used when entering L1 to stall progression into L1 substates
  input                                 aux_clk_inactive,             // PM Clock Controller: muxed aux clk has switched to core clock
  input                                 pm_en_core_clk,               // PM Clock Controller: Enable core_clk
  input                                 pm_linkst_en_core_clk,        // PM Clock Controller: Enable core_clk
  output logic                          pm_linkst_sel_aux_clk,        // PM Clock Controller: Select slow clock for aux_clk
  output logic                          pm_l1sub_sel_aux_clk,         // PM Clock Controller:
  input                                 pm_clkreq_in_n,               // PM Wake: Status of the CLKREQ# bidirectional CMOS board-level signal, used for remotely initiated exit from L1 substates
  input                                 pm_perst_powerdown,           // PM Reset Controller: Drive specific powerdown during phy_perst rst
  input                                 pm_req_non_sticky_rst,        // PM Reset Controller: Request the assertion of sticky, core, non_sticky resets
  input                                 pm_phy_rst_done,              // PM Reset Controller: Reset of PHY after L2 exit is complete
  input                                 pm_det_l2,                    // PM Reset Controller: Indication that main power has been removed and core is in L2 with perst asserted
  input                                 pre_pm_exit_p2,               // PM Reset Controller: Indicates P2 exit in the next cycle
  input                                 pm_set_phy_p1,                // PM Reset Controller: When the PHY is reset in L2 the powerdown is set to P1
  input                                 pm_l1sub_fsm_rst,             // PM Reset Controller: Reset L1 Substate FSM
  output logic                          pm_linkst_in_l23rdy,          // PM Reset Controller/PMU/Gasket/Application: Power management is in L2 ready state
  input                                 gasket_maxpclk_removed,       // Gasket: Indicate that maxpclk is removed
  input                                 gasket_maxpclk_back_on,       // Gasket: Indicate that maxpclk is turned on in P1CPM
  input                                 gasket_drive_pd,              // Gasket: Gasket it driving powerdown
  input                                 gasket_drive_pd_no_clk,       // Gasket: Gasket it driving p1cpm, p11 or p12, in which ref clk is removed
  input                                 gasket_clk_req_n,             // Gasket: Powerdown is P1.CPM controller de-asserts clk_req_n
  input                                 gasket_powerdown_p1_2,        // Gasket: Powerdown value P1.2 driven by the pipe4.3 gasket
  input                                 gasket_sel_aux_clk,           // Gasket: allow switching of aux_clk when P1.CPM transition has occured
  output logic                          pm_req_exit_p2,               // Gasket: PM block request to transition powerdown from p2 to p1
  output logic                          cfg_trgt_l1cpm,               // Gasket: 
  output logic                          l1sub_state_is_l1_u,          // Gasket: L1 substates when NOT L1 unmodified
  output logic [1:0]                    cfg_trgt_l1sub,               // Gasket: 
  output logic                          l1sub_l11_next,               // Gasket: 
  output logic                          l1sub_l12_next,               // Gasket: 
  output logic                          l1sub_abort_next,             // Gasket: 
  output logic                          l1sub_req_p1cpm,              // Gasket: 
  output logic                          pm_l1sub_clk_req_n,           // Gasket: 
  output logic                          pm_l1_cpm_exit,               // Gasket
  output logic [(PD_WIDTH - 1) : 0]     pm_phy_powerdown,             // Gasket/PHY_IF_CPCIE: PM to PHY power down
  input  [NL*PHY_TXEI_WD-1:0]           ltssm_txelecidle,             // PHY_IF_CPCIE: LTSSM tells PHY to go into electrical idle
  output logic                          mac_phy_rxelecidle_disable,   // PHY_IF_CPCIE: disable rx electrical idle detection circuits
  output logic                          mac_phy_txcommonmode_disable, // PHY_IF_CPCIE: disable tx common mode circuits
  input  [NL-1:0]                       pm_lane_active,               // PHY_STATUS_IF: Active lanes
  input                                 current_powerdown_p2,         // PHY_STATUS_IF: Current powerdown is P2. PHY has acknowledged P2 transition with Phystatus on all active lanes
  input                                 pmu_l2_pd,                    // PMU: Flag to indicate L2 power gating process is in progress
  input                                 pm_req_iso_vmain_to_vaux,     // PMU: Enable for isolation cells on boundary from VMAIN to VAUX
  output logic                          pm_l1sub_pg_enable,           // PMU: Link is in L1.2 indicate power can be removed
  output logic                          pm_l1sub_pg_disable,          // PMU: Link is exiting L1.2 indicate power can be restored
  output logic                          pm_state_trans3_flag,         // LTSSM Latency Tracker: L1.0 to L0.
  output logic                          pm_state_trans4_flag,         // LTSSM Latency Tracker: L1.1 to L0.
  output logic                          pm_state_trans5_flag,         // LTSSM Latency Tracker: L1.2 to L0.
  //------------------------------------------------------------------------------
  // Link Layer Interface
  //------------------------------------------------------------------------------
  input                                 lp_sdb_l1sub_aspm,            // SDLH Protocol FSM: Sideband signal that indicates ASPM L1 Entry for L1-substates implementation in the LogPHY
  input                                 lp_sdb_l1sub_pcipm,           // SDLH Protocol FSM: Sideband signal that indicates PCI-PM L1 Entry for L1-substates implementation in the LogPHY
  input                                 pm_clk_ack,                   // PM Link Controller: Link Layer acknowledges pm_clk_req
  output logic                          pm_clk_req                    // PM Link Controller: LogPHY request to remove Link Layer clock gating
);

// -----------------------------------------------------------------------------
// --- Local Parameters
// -----------------------------------------------------------------------------
localparam US_TIMER_WD          = log2roundup(100000); // = 12 bits, use function for readability only, number of bits to count worst case which is t_power_on_value = 31 with a scale of 100us

//------------------------------------------------------------------------------
// Internal signals declaration
//------------------------------------------------------------------------------
logic [1:0]                   pm_l1sub_mac_phy_pclkreq_n;
logic                         int_pd_p1_override;
logic                         int_update_powerdown;
logic                         int_block_pd_update;
logic                         int_detect_pd_update;
logic                         int_smlh_pd_update;
logic                         int_txelecidle_and;
logic                         int_p0_pd_update;
logic                         int_idle_next;
logic                         int_upd_clk_req_n;
logic                         int_hold_clk_req_n;
logic                         int_pm_clk_req_n;
logic                         int_pm_l2_wakeup;
logic [NL*PHY_TXEI_WD-1:0]    int_phy_txelecidle;
logic                         int_phy_beacongen;
logic                         int_l2_wakeup_done;
logic [NL*PHY_TXEI_WD-1:0]    int_phy_txelecidle_r;
logic                         int_sel_pm_txelecidle;
logic                         int_drive_txelecidle;
logic                         int_sel_pm_txelecidle_r;
logic                         sync_phy_clk_req_n;
logic                         int_phy_clk_req_n_r;
logic                         int_phy_clk_req_n;
logic                         int_lp_clk_sw_mode;
logic                         ltssm_track_l1sub_exit; // inform exit from l1 substate
logic                         pm_perst_powerdown_r;
logic                         int_rxelecidle_deassert;
logic [NL-1:0]                sync_phy_rxelecidle;        // internal synchronized version of phy_mac_rxelecidle due to the asynchronous nature of this signal
logic [NL-1:0]                int_active_lane_rxelecidle;
logic [NL-1:0]                int_active_lane_rxelecidle_r;
logic                         zrxdc_us_timer_clear;       // 8 GT/s Rx Impedance ECN 1 us timer clear signal
logic [US_TIMER_WD-1:0]       zrxdc_us_timer;             // 8 GT/s Rx Impedance ECN 1 us timer clear signal
logic                         timeout_t_100ms;            // 8 GT/s Rx Impedance ECN - 100 ms timeout flag
logic                         pm_phy_beacongen;
logic                         aux_clk_en_1us;
logic                         int_block_l1_exit;
logic                         next_pm_state_is_l1;
logic                         pm_active_next_l1;
logic                         pm_active_next_l23;
logic                         timer2;


// -----------------------------------------------------------------------------
// Output assignments
// -----------------------------------------------------------------------------
// replicate phy powerdown to avoid any potential issues with fanout to 2 power domains
assign pm_int_phy_powerdown = pm_phy_powerdown;
// Current PM state (TOBEREMOVED).
assign pm_curnt_state = 3'b000;

// Preserving these two internal signals to avoid the change in hierarchical references at the moment (TOBEREMOVED)
logic  int_l1_exit;
logic  latch_int_l1_exit;

assign int_l1_exit       = pm_active_next_l1 && pm_wakeup_event;
assign latch_int_l1_exit = pm_link_exit_l1;



// -----------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Freeze logic when the power down has been requested (will prevent wrong
// transitions between the powerdown request and the oactual power down arrival).
//------------------------------------------------------------------------------
logic int_pd_p2_r;

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : pd_p2_PROC
    if (!pwr_rst_n)
        int_pd_p2_r <= #TP 1'b0;
    // if perst is asserted abort the handshake since we will reset the PHY on perst de-assertion
    else if (!perst_n || current_powerdown_p2)
        int_pd_p2_r <= #TP 1'b1;
    // clear the flag
    else if (!((pm_usp_link_state == USP_LINK_L23RDY) || (pm_dsp_link_state == DSP_LINK_L23RDY)))
        int_pd_p2_r <= #TP 1'b0;
    else
        int_pd_p2_r <= #TP int_pd_p2_r;
end : pd_p2_PROC
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// L23 state control (former WAIT4ALIVE Link FSM state implementation)
// ----------------------------------------------------------------------------
typedef enum {
   PM_LINK_FSM_IDLE,
   PM_LINK_FSM_L23RDY,
   PM_LINK_FSM_WAIT4ALIVE,
   PM_LINK_FSM_WAIT4LINKUP
} PM_LINK_FSM_t;

PM_LINK_FSM_t  pm_link_fsm_r, pm_link_fsm_nxt;

assign pm_link_exit_l23 = (pm_link_fsm_r == PM_LINK_FSM_WAIT4LINKUP);

always_comb begin
    if (perst_n_posedge) begin
        pm_link_fsm_nxt = PM_LINK_FSM_WAIT4LINKUP;
    end else begin
        pm_link_fsm_nxt = pm_link_fsm_r;

        case (pm_link_fsm_r)
            PM_LINK_FSM_L23RDY: begin
                // Hold until P2 transition is acknowledged by the PHY
                if (int_pd_p2_r) begin
                    // This transition exists only for DSP
                    if (pm_phy_rst_done && !upstream_port)
                        pm_link_fsm_nxt = PM_LINK_FSM_WAIT4LINKUP;
                    else if (int_rxelecidle_deassert && !pmu_l2_pd)
                        pm_link_fsm_nxt = PM_LINK_FSM_WAIT4LINKUP;
                    else if (pm_wakeup_event)
                        pm_link_fsm_nxt = PM_LINK_FSM_WAIT4ALIVE;
                end
            end
            PM_LINK_FSM_WAIT4ALIVE: begin
                if (int_rxelecidle_deassert && !pmu_l2_pd)
                    pm_link_fsm_nxt = PM_LINK_FSM_WAIT4LINKUP;
            end
            PM_LINK_FSM_WAIT4LINKUP: begin
                if (pm_en_core_clk)
                    pm_link_fsm_nxt = PM_LINK_FSM_IDLE;
            end
            default: begin
                if (pm_active_next_l23)
                    pm_link_fsm_nxt = PM_LINK_FSM_L23RDY;
            end
        endcase
    end
end

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n)
        pm_link_fsm_r <=  #TP PM_LINK_FSM_IDLE;
    else
        pm_link_fsm_r <=  #TP pm_link_fsm_nxt;
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Link FSM state signals
// ----------------------------------------------------------------------------
logic  dsp_link_l23rdy;
logic  dsp_link_l1_exit;
logic  usp_link_l1_link_entr_l1;
logic  usp_link_l1;
logic  usp_link_l1_exit;
logic  usp_link_l23rdy;
logic  usp_link_rst;
logic  usp_link_recovery;
usp_link_fsm_state_e     pm_usp_link_state_d;            // Register PM Link FSM State
dsp_link_fsm_state_e     pm_dsp_link_state_d;            // Register PM Link FSM State
logic                    pm_linkst_l2_exit_s;            // Combinational logic for pm_linkst_l2_exit

assign dsp_link_l23rdy          = (pm_dsp_link_state == DSP_LINK_L23RDY);
assign dsp_link_l1_exit         = (pm_dsp_link_state == DSP_LINK_L1_EXIT);
assign usp_link_l1_link_entr_l1 = (pm_usp_link_state == USP_LINK_L1_LINK_ENTR_L1);
assign usp_link_l1              = (pm_usp_link_state == USP_LINK_L1);
assign usp_link_l1_exit         = (pm_usp_link_state == USP_LINK_L1_EXIT);
assign usp_link_l23rdy          = (pm_usp_link_state == USP_LINK_L23RDY);
assign usp_link_rst             = (pm_usp_link_state == USP_LINK_RST);
assign usp_link_recovery        = (pm_usp_link_state == USP_LINK_RECOVERY);

assign pm_active_next_l1        = (pm_usp_link_state == USP_LINK_L1) || (pm_dsp_link_state == DSP_LINK_L1);
assign pm_active_next_l23       = ((pm_usp_link_state inside {USP_LINK_L23RDY, USP_LINK_L23RDY_WAIT4ALIVE}) || (pm_dsp_link_state inside {DSP_LINK_L23RDY, DSP_LINK_L23RDY_WAIT4ALIVE})) && !pm_link_exit_l23;

// During L2 exit, the core_clk might be disabled. The capture of link fsm
// state has to be done in aux_clk domain.
assign pm_linkst_l2_exit_s = ( ((pm_usp_link_state_d == USP_LINK_L23RDY) && (pm_usp_link_state != USP_LINK_L23RDY))
                               || ((pm_dsp_link_state_d == DSP_LINK_L23RDY) && (pm_dsp_link_state != DSP_LINK_L23RDY)) ) && aux_pm_det;

always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n) begin
        pm_linkst_in_l0             <= #TP 1'b0;
        pm_linkst_in_l1             <= #TP 1'b0;
        pm_linkst_in_l23rdy         <= #TP 1'b0;
        pm_linkst_in_l2             <= #TP 1'b0;
        pm_linkst_l2_exit           <= #TP 1'b0;
        pm_linkst_in_l3             <= #TP 1'b0;
        pm_linkst_in_l1sub          <= #TP 1'b0;
        pm_usp_link_state_d         <= #TP USP_LINK_RST;
        pm_dsp_link_state_d         <= #TP DSP_LINK_RST;
    end
    else begin
        pm_linkst_in_l0             <= #TP (pm_usp_link_state == USP_LINK_L0) || (pm_dsp_link_state == DSP_LINK_L0);
        pm_linkst_in_l1             <= #TP pm_active_next_l1;
        pm_linkst_in_l23rdy         <= #TP (pm_usp_link_state == USP_LINK_L23RDY) || (pm_dsp_link_state == DSP_LINK_L23RDY);
        pm_linkst_in_l2             <= #TP pm_active_next_l23 && aux_pm_det && !perst_n;
        pm_linkst_l2_exit           <= #TP pm_linkst_l2_exit_s;
        pm_linkst_in_l3             <= #TP pm_active_next_l23 && !aux_pm_det && !perst_n;
        pm_linkst_in_l1sub          <= #TP !l1sub_state_is_l1_u; // L1 substates when NOT L1 unmodified
        pm_usp_link_state_d         <= #TP pm_usp_link_state;
        pm_dsp_link_state_d         <= #TP pm_dsp_link_state;
    end
end
// ----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
// Clock Request
// -----------------------------------------------------------------------------
logic  int_pm_clk_req_s;
logic  int_pm_clk_req_r;

assign pm_clk_req = (int_pm_clk_req_s && !pm_clk_ack) || int_pm_clk_req_r;

assign int_pm_clk_req_s = (    int_rxelecidle_deassert                   // PHY detected electric idle exit. This is useful for identify PHY exit to command PM state change for application that intended to not supply clock
                            || timeout_t_100ms                           // 8 GT/s Rx Impedance ECN - 100 ms timout when in L1.
                          ) && (pm_active_next_l1 || pm_active_next_l23);

// Latched internal WakeUp request
always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n)
        int_pm_clk_req_r <=  #TP 1'b0;
    // After receiving pm_clk_ack wait for status change to release pm_clk_req.
    // This is required to prevent back-to-back request/acknowledges.
    else if (pm_clk_ack && !(pm_active_next_l1 ||pm_active_next_l23))
        int_pm_clk_req_r <=  #TP 1'b0;
    else if (pm_clk_req)
        int_pm_clk_req_r <=  #TP 1'b1;
end
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// L1 Exit Control
// -----------------------------------------------------------------------------
assign pm_l1_cpm_exit = pm_link_exit_l1 || !phy_link_up;


always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n)
        pm_link_exit_l1 <=  #TP 1'b0;
    else if (pm_active_next_l1 && pm_wakeup_event)
        pm_link_exit_l1 <=  #TP 1'b1;
    else if ( !pm_active_next_l1 )
        pm_link_exit_l1 <=  #TP 1'b0;
end
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// Time Tick generator
// -----------------------------------------------------------------------------

DWC_pcie_tim_gen
 #(
    .CLEAR_CNTR_TO_1 (0)
) u_gen_timer2
(
     .clk               (aux_clk)
    ,.rst_n             (pwr_rst_n)

    ,.current_data_rate (current_data_rate)
    ,.clr_cntr          (1'b0)        // clear cycle counter(not used in this timer)

    ,.cnt_up_en         (timer2)  // timer count-up
);

// -----------------------------------------------------------------------------
// Clock enabling logic
// -----------------------------------------------------------------------------
wire   int_pm_clk_pm_en;
assign int_pm_clk_pm_en = smlh_cal_req ? 0 :
                          pm_cxl_mode_enable ? 0 :
                          pm_clk_pm_en;

// mask the fast exit mode is the target state is not L1 sub-states
wire int_mask_fast_exit_mode;
assign int_mask_fast_exit_mode = (|cfg_trgt_l1sub) && pm_pl_l1sub_control[(PL_L1SUB_CONTROL_WD - 1)];

// If Pipe4.3 or later is supported delay clock switching until P1.CPM entry to insure P1.CPM is driven synchronous to PCLK 
wire int_pipe43_sel_aux_clk;
assign int_pipe43_sel_aux_clk = ( int_pm_clk_pm_en || (|cfg_trgt_l1sub)) && gasket_sel_aux_clk;

// pm link state FSM requests aux_clk switch in L1 and powerdown is P1 and when L1 sub-fast exit mode is not enabled, or in L2 when powerdown is P2
// aux clk should be switched even the state is in L23RDY
assign pm_linkst_sel_aux_clk =  (
                                  (pm_active_next_l1 && !pm_linkst_en_core_clk) && 
                                  ((!pl_l1_clk_sel || int_pm_clk_pm_en || (|cfg_trgt_l1sub)) && !int_mask_fast_exit_mode)
 && int_pipe43_sel_aux_clk
                                ) || 
                                ( 
                                  (pm_active_next_l23 || gasket_sel_aux_clk) && 
                                  (pre_pm_phy_powerdown == P2) && !gasket_maxpclk_back_on
                                );

assign pm_phyinl1 = pm_active_next_l1  && ((pre_pm_phy_powerdown == P1));
assign pm_phyinl2 = pm_active_next_l23 && (pre_pm_phy_powerdown == P2);

assign pm_en_core_clk_gating = !smlh_cal_req && !gasket_maxpclk_back_on ;


// -----------------------------------------------------------------------------
// Clock request logic
// -----------------------------------------------------------------------------

assign int_upd_clk_req_n = gasket_clk_req_n;
  
// when isolated do not update value of clk_req_n
assign int_hold_clk_req_n = pm_req_iso_vmain_to_vaux ? local_ref_clk_req_n : int_upd_clk_req_n;

// gate the de-assertion of CLKREQ# with the PHY reference clock request signal
assign int_lp_clk_sw_mode = pm_pl_l1sub_control[(PL_L1SUB_CONTROL_WD - 1)];

// If the reference clock is always on controller does not wait for PHY clkreq handshake.
assign int_phy_clk_req_n = int_lp_clk_sw_mode ? 1'b1 : int_phy_clk_req_n_r;

assign int_pm_clk_req_n = app_clk_req_n && (int_hold_clk_req_n || gasket_clk_req_n) && int_phy_clk_req_n;

always @(posedge aux_clk or negedge pwr_rst_n) begin
  if (!pwr_rst_n) begin
    local_ref_clk_req_n     <= #TP 1'b0;
  end else begin
    // When asserted to 1'b1, then it is ok to turn off the reference clock.
    local_ref_clk_req_n <= #TP int_pm_clk_req_n && perst_n;
  end
end
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// PHY-related outputs (reactivate and electrical idle)
// -----------------------------------------------------------------------------
assign wake = pm_phy_beacongen;

// Select between LTSSM and PM version of txelecidle. LTSSM version is not
// registered to avoid adding delay
assign pm_phy_txelecidle = int_sel_pm_txelecidle_r ? int_phy_txelecidle_r : ltssm_txelecidle;

// Link state is in L2 and wakeup event is detected
assign int_pm_l2_wakeup = (pm_wakeup_event && pm_active_next_l23);

// The wakeup from L2 is completed when perst_n rising edge is detected or
// in the case where perst_n has not been asserted when rxelecidle is
// deasserted
assign int_l2_wakeup_done = int_pm_l2_wakeup && (pm_set_phy_p1 || int_rxelecidle_deassert);

assign int_drive_txelecidle = aux_clk_active;
assign int_sel_pm_txelecidle = ((pm_active_next_l23 || pm_linkst_in_l1) && aux_clk_active);

// TXELECIDLE it will be set to 1 if in P0S or P1 or if in P2 with no
// wakeup event. When wakeup event is detected in P2 it will be set to 0 to
// allow for beacon transmission. Otherwise it will take the value provided
// by the LTSSM
// The beacongen signal is used to drive the wake signal which should be
// used by power management circuitry to restore main power in L2
always_comb begin
    if(!int_drive_txelecidle) begin
        int_phy_txelecidle = ltssm_txelecidle;
        int_phy_beacongen = 1'b0;
    end else if(int_l2_wakeup_done) begin
        int_phy_txelecidle = {NL*PHY_TXEI_WD{1'b1}};
        int_phy_beacongen = 1'b0;
    end else if(int_pm_l2_wakeup) begin
        if (!pm_perst_powerdown_r) begin
          int_phy_txelecidle = {NL*PHY_TXEI_WD{1'b0}};
        end else begin
          int_phy_txelecidle = {NL*PHY_TXEI_WD{1'b1}};
        end
        int_phy_beacongen = 1'b1;
    end else begin
        int_phy_txelecidle = int_phy_txelecidle_r;
        int_phy_beacongen = 1'b0;
    end
end

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if(!pwr_rst_n) begin
        int_sel_pm_txelecidle_r <= #TP 1'b0;
        int_phy_txelecidle_r    <= #TP {NL*PHY_TXEI_WD{1'b1}};
        pm_phy_beacongen        <= #TP 1'b0;
        pm_perst_powerdown_r    <= #TP 1'b0;
    end else begin
        int_sel_pm_txelecidle_r <= #TP int_sel_pm_txelecidle;
        int_phy_txelecidle_r    <= #TP int_phy_txelecidle;
        pm_phy_beacongen        <= #TP int_phy_beacongen;
        // delay pm_perst_powerdown by 1 clock cycle
        pm_perst_powerdown_r    <= #TP pm_perst_powerdown;
    end
end
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// PM powerdown
// -----------------------------------------------------------------------------

// Dont detect powerdown updates from the LTSSM in the following cases 
// Isolation is enabled
// Dont take P2 from the LTSSM since the clock must switch to aux_clk first
// In L1 substates dont allow powerdown to update until the PHY has asserted phy_mac_pclkack_n
assign int_block_pd_update = pm_det_l2 || smlh_in_l23 || pm_req_iso_vmain_to_vaux || (pre_pm_phy_powerdown == P2);

assign int_detect_pd_update = !(pre_pm_phy_powerdown == pm_phy_powerdown);

// LTSSM updates powerdown based on state transition for example L1 to RECOVERY txelecidle is not asserted
assign int_smlh_pd_update = (int_detect_pd_update 
                            && !int_block_pd_update 
                            && !int_block_l1_exit
                            );
// When transitioning from P0 the txelecidle must be asserted
assign int_txelecidle_and = &ltssm_txelecidle;
assign int_p0_pd_update = (pm_phy_powerdown == P0) && int_smlh_pd_update && int_txelecidle_and;

// Update powerdown signal block updates if powerdown is overriden to P2 or perst_n is asserted
// Also do not take updates to powerdown before the PHY has asserted phy_clk_req_n
assign int_update_powerdown = perst_n && (!int_pd_p1_override && (int_p0_pd_update || (!(pm_phy_powerdown == P0) && int_smlh_pd_update)));
assign pm_req_exit_p2 = (pm_set_phy_p1 || (pm_active_next_l23 && int_rxelecidle_deassert && !pm_det_l2 && current_powerdown_p2));

// drive powerdown from the pm_ctrl in these states this prevents a deadlock situation where
// powerdown is driven to P2 by the LTSSM long before the pm controller has entered L2 and switched
// to aux_clk
always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n)
        pm_phy_powerdown    <= #TP P1;
    // Set powerdown to P1 during pma phy reset triggered by fundamental reset
    else if (pm_perst_powerdown)
        pm_phy_powerdown    <= #TP P1;
    // Set powerdown to P1 only after txelecidle has been asserted
    else if (pm_req_exit_p2)
        pm_phy_powerdown    <= #TP P1;
    // When the FSM is in L23RDY or L23RDY_WAIT4ALIVE drive P2 to the PHY
    else if (pm_active_next_l23 && !pre_pm_exit_p2)
        // Do not drive P2/P2.NoBeacon one cycle before P2 exit. This avoids invalid transition after perst rst.
        pm_phy_powerdown    <= #TP pm_cfg_phy_powerdown_p2_options;
    else if ((!link_req_rst_not && int_txelecidle_and))
        pm_phy_powerdown    <= #TP P1;
    else if (gasket_drive_pd)
        pm_phy_powerdown    <= #TP P1;
    else if (int_update_powerdown)
        pm_phy_powerdown    <= #TP pre_pm_phy_powerdown;
    else
        pm_phy_powerdown    <= #TP pm_phy_powerdown;
end
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// Synchronize PHY signal to aux clock.
// -----------------------------------------------------------------------------
DWC_pcie_ctl_bcm41

#(
    .WIDTH (1),
    .RST_VAL (0),
    .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_phy_clk_req_n_sync (
    .clk_d      (aux_clk),
    .rst_d_n    (pwr_rst_n),
    .data_s     (phy_clk_req_n),
    .data_d     (sync_phy_clk_req_n)
);

always @(posedge aux_clk or negedge pwr_rst_n) begin : phy_clk_req_PROC
  if(!pwr_rst_n) begin
    int_phy_clk_req_n_r <= #TP 1'b0;
  end else begin
    int_phy_clk_req_n_r <= #TP sync_phy_clk_req_n;
  end
end : phy_clk_req_PROC

// -----------------------------------------------------------------------------
// Generating signal that blocks L1 exit (waiting for PHY to accept clock).
// Also, logic for the override of the PM state.
// -----------------------------------------------------------------------------
assign int_block_l1_exit = gasket_drive_pd;  
assign pm_hold_exit_l1 = int_block_l1_exit;
// There is no override of P1 to P2 if pipe43 support is enabled P1.CPM
// encoding on the powerdown bus is used to disable ref clock
assign int_pd_p1_override = 1'b0;

// -----------------------------------------------------------------------------
// RX EIDLE Deassertion detect.
// -----------------------------------------------------------------------------
// if the squelch module is defined, then it will synchronize phy_mac_rxelecidle.
assign  sync_phy_rxelecidle = phy_mac_rxelecidle;

// Only detect electrical idle de-assertion on active lanes for exiting low power
always @(posedge aux_clk or negedge pwr_rst_n) begin : rxelecidle_active_PROC
  if(!pwr_rst_n)
    int_active_lane_rxelecidle_r <= #TP {NL{1'b0}};
  else
    int_active_lane_rxelecidle_r <= #TP int_active_lane_rxelecidle;
end : rxelecidle_active_PROC

assign int_active_lane_rxelecidle = sync_phy_rxelecidle | ~pm_lane_active; 

assign int_rxelecidle_deassert = !(&int_active_lane_rxelecidle_r);

// -----------------------------------------------------------------------------
// L1Sub FSM.
// -----------------------------------------------------------------------------
assign next_pm_state_is_l1 = pm_linkst_in_l1 && !pm_link_exit_l1;

assign cfg_trgt_l1cpm = int_pm_clk_pm_en;

wire int_l1sub_sel_aux_clk;

assign pm_l1sub_sel_aux_clk = int_l1sub_sel_aux_clk && int_pipe43_sel_aux_clk;

pm_active_ctrl_l1sub

#(  .INST                 (INST),
    .PM_CPL_TIMER_WD      (PM_CPL_TIMER_WD),
    .L1SUB_CONTROL_WD     (L1SUB_CONTROL_WD),
    .PL_L1SUB_CONTROL_WD  (PL_L1SUB_CONTROL_WD),
    .PM_SYNC_DEPTH        (PM_SYNC_DEPTH)
) u_pm_active_ctrl_l1sub (
// ---- inputs ---------------
    .aux_clk                     (aux_clk),
    .aux_clk_en_1us              (aux_clk_en_1us),
    .pwr_rst_n                   (pwr_rst_n),
    .next_pm_state_is_l1         (next_pm_state_is_l1),
    .smlh_in_l0                  (smlh_in_l0),
    .latch_int_l1_exit           (pm_link_exit_l1),
    .phy_link_up                 (phy_link_up),
    .aux_clk_active              (aux_clk_active),
    .aux_clk_inactive            (aux_clk_inactive),
    .phy_mac_pclkack_n           (phy_mac_pclkack_n),
    .gasket_powerdown_p1_2       (gasket_powerdown_p1_2),
    .pm_clkreq_in_n              (pm_clkreq_in_n),
    .cfg_l1sub_control           (pm_l1sub_control),
    .cfg_pl_l1sub_control        (pm_pl_l1sub_control),
    .cfg_trgt_l1cpm              (cfg_trgt_l1cpm),
    .aspm_l1_entry               (lp_sdb_l1sub_aspm),
    .pcipm_l1_entry              (lp_sdb_l1sub_pcipm),
    .app_l1sub_disable           (app_l1sub_disable), // Gate the L1 sub-states enable bits
    .gasket_maxpclk_removed      (gasket_maxpclk_removed),
    .pm_req_non_sticky_rst       (pm_req_non_sticky_rst), 
    .pm_l1sub_fsm_rst            (pm_l1sub_fsm_rst), 
    .cxl_link_enable             (pm_cxl_mode_enable),
    .smlh_cal_req                (smlh_cal_req),
// ---- outputs ---------------
    .cfg_trgt_l1sub              (cfg_trgt_l1sub),
    .l1sub_l11_next              (l1sub_l11_next),
    .l1sub_l12_next              (l1sub_l12_next),
    .l1sub_abort_next            (l1sub_abort_next),
    .l1sub_req_p1cpm             (l1sub_req_p1cpm),
    .mac_phy_pclkreq_n           (pm_l1sub_mac_phy_pclkreq_n),
    .mac_phy_rxelecidle_disable  (mac_phy_rxelecidle_disable),
    .mac_phy_txcommonmode_disable(mac_phy_txcommonmode_disable),
    .l1sub_smlh_l1_2_latched     (pm_smlh_l1_2_latched),
    .l1sub_smlh_l1_n_latched     (pm_smlh_l1_n_latched),
    .l1sub_state_is_l1_u         (l1sub_state_is_l1_u),
    .l1sub_pg_enable             (pm_l1sub_pg_enable),
    .l1sub_pg_disable            (pm_l1sub_pg_disable),
    .l1sub_state                 (l1sub_state)
   ,.pm_in_l11                   (pm_in_l11),
    .pm_in_l12                   (pm_in_l12),
    .pm_in_l1_short              (pm_in_l1_short),
    .pm_in_l1_cpm                (pm_in_l1_cpm),
    .pm_in_l1_abort              (pm_in_l1_abort)
    ,
    .l1sub_clk_req_n             (pm_l1sub_clk_req_n),
    .l1sub_sel_aux_clk           (int_l1sub_sel_aux_clk)
    ,
    .pm_pclkack_timeout          (pm_pclkack_timeout)
    ,
    .ltssm_track_l1sub_exit      (ltssm_track_l1sub_exit)
);

// -----------------------------------------------------------------------------
// Generate markers for every 1 us of aux clock (being it core clock, or the
// slowed down version).
// -----------------------------------------------------------------------------
pm_active_ctrl_aux_timer
 u_pm_active_ctrl_aux_timer (
// ---- inputs ---------------
    .aux_clk                     (aux_clk),
    .pwr_rst_n                   (pwr_rst_n),
    .aux_clk_freq                (pm_pl_aux_clk_freq),
    // Switch to timer that runs on core_clk_ug to keep 1us duration
    .timer2                      (timer2),
    .aux_clk_active              (aux_clk_active),

// ---- outputs ---------------
    .en_1us                      (aux_clk_en_1us)
);

// -----------------------------------------------------------------------
// 100 ms Timer for 8 GT/s Receiver Impedance ECN.
// -----------------------------------------------------------------------

// 1 us timer is cleared when device is not in L1 state or
//                       when PHY does comply with Zrx-dc impedance requirement or
//                       when current_data_rate != `GEN3_RATE.

assign zrxdc_us_timer_clear = ( !pm_active_next_l1 || !pm_pl_gen3_zrxdc_noncompl ||
                                !((current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE || current_data_rate == `GEN6_RATE )) );
always @(posedge aux_clk or negedge pwr_rst_n) begin : zrxdc_us_timer_PROC
    if (!pwr_rst_n) begin
        zrxdc_us_timer <= #TP 0;
    end else if (zrxdc_us_timer_clear) begin
        zrxdc_us_timer <= #TP 0;
    end else if( aux_clk_en_1us ) begin
        zrxdc_us_timer <= #TP zrxdc_us_timer + 1'b1; // free running is ok provided the timeout flags are sticky, i.e. don't get reset after the timer rolls over
    end
end

// Timeout flag
always @(posedge aux_clk or negedge pwr_rst_n) begin : zrxdc_timeout_PROC
    if (!pwr_rst_n) begin
        timeout_t_100ms   <= #TP 1'b0;
    end else if (zrxdc_us_timer_clear) begin
        timeout_t_100ms   <= #TP 1'b0;
    end else begin
        if (aux_clk_en_1us) begin // wait next 1us clock enable to compensate for the initial us_timer increment which may be shorter than 1us
          if (zrxdc_us_timer == 100000) begin
              timeout_t_100ms   <= #TP 1'b1;
          end
        end
    end
end

function automatic integer log2roundup(input integer value);
    begin
        log2roundup = 1;
        while(1<<log2roundup <= value)
            log2roundup = log2roundup + 1;

    end
endfunction

// -----------------------------------------------------------------------
// Generate PM State transition signals, which will be used to monitor the
// delay betweent the request to enter L1 and the actual L1 entry in smlh.
// -----------------------------------------------------------------------
// Timeout flag
always @(posedge aux_clk or negedge pwr_rst_n) begin : pm_stat_trans_flag_PROC
  if (!pwr_rst_n) begin
    pm_state_trans3_flag      <= #TP 1'b0;
    pm_state_trans4_flag      <= #TP 1'b0;
    pm_state_trans5_flag      <= #TP 1'b0;
  end else begin
    if(l1sub_l11_next && ltssm_track_l1sub_exit) begin
      pm_state_trans4_flag    <= #TP 1'b1;
    end else if(l1sub_l12_next && ltssm_track_l1sub_exit) begin
      pm_state_trans5_flag    <= #TP 1'b1;
    end else begin
    if(pm_link_exit_l1 && pm_active_next_l1) begin
        pm_state_trans3_flag  <= #TP 1'b1;
    end    
    end
    if (smlh_in_l0) begin
      pm_state_trans3_flag      <= #TP 1'b0;
      pm_state_trans4_flag      <= #TP 1'b0;
      pm_state_trans5_flag      <= #TP 1'b0;
    end
  end
end : pm_stat_trans_flag_PROC


endmodule // pm_active_ctrl
