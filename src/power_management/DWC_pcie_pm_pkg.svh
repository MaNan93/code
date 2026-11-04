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

// -----------------------------------------------------------------------------
// ---  RCS information:
// ---    $Author: lnicola $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/DWC_pcie_pm_pkg.svh#12 $
// -----------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_PM_PKG__SVH__
`define __GUARD__DWC_PCIE_PM_PKG__SVH__

`include "products/cx_pl_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"

// -----------------------------------------------------------------------------
// --- Package Description: Enumerated types to define PM FSM state encodings
// -----------------------------------------------------------------------------

package DWC_pcie_pm_pkg;

  // PM Active Control Master State Encodings
  typedef enum logic [3:0] {
    IDLE,           // Idle state (P0, P0S)
    PD_P1,          // P1 state
    PD_P2,          // P2 state
    PD_P1_CPM,      // P1.CPM state
    PD_P1_1,        // P1.1 state
    PD_P1_2,        // P1.2 state
    PD_TPOWER_ON,   // Wait Tpower_on after exiting L1 sub-states
    ASYNC_HS_ENTER, // Start the asynchronous handshake with the PHY
    ASYNC_HS_EXIT,  // Asynchronous handshake with the PHY complete
    WAIT_PM_L1      // Wait for the pm_active_ctrl module to enter L1
    ,MAXPCLK_OFF,    // request MAXPLCK removal
    MAXPCLK_ON       // request MAXPCLK recovery
  } pd_fsm_state_e;

  // Upstream Port PM Protocol Negotiation FSM Encodings
  typedef enum logic [3:0] {
    USP_PROT_RST                   = 4'h0,
    USP_PROT_RECOVERY              = 4'h1,
    USP_PROT_ACTIVE                = 4'h2,
    USP_PROT_ENTER_L0S             = 4'h3,
    USP_PROT_ENTER_L1              = 4'h4,
    USP_PROT_L1_BLOCK_TLP          = 4'h5,
    USP_PROT_L1_WAIT_LAST_TLP_ACK  = 4'h6,
    USP_PROT_L1_WAIT_PMDLLP_ACK    = 4'h7,
    USP_PROT_ENTER_L23             = 4'h8,
    USP_PROT_L23_BLOCK_TLP         = 4'h9,
    USP_PROT_L23_WAIT_LAST_TLP_ACK = 4'hA,
    USP_PROT_L23_WAIT_PMDLLP_ACK   = 4'hB,
    USP_PROT_WAIT_PMCSR_CPL_SENT   = 4'hC,
    USP_PROT_WAIT_LAST_PMDLLP      = 4'hD,
    USP_PROT_WAIT_CXS_IDLE         = 4'hE,
    USP_PROT_WAIT_DSTATE_UPDATE    = 4'hF
  } usp_prot_fsm_state_e;

  // Upstream Physical Link Control FSM Encodings
  typedef enum logic [3:0] {
    USP_LINK_RST                = 4'h0,
    USP_LINK_RECOVERY           = 4'h1,
    USP_LINK_ABORT              = 4'h2,
    USP_LINK_L0                 = 4'h3,
    USP_LINK_PREP_4L1           = 4'h4,
    USP_LINK_L1_LINK_ENTR_L1    = 4'h5,
    USP_LINK_L1                 = 4'h6,
    USP_LINK_L1_EXIT            = 4'h7,
    USP_LINK_WAIT_DSTATE_UPDATE = 4'h8,
    USP_LINK_PREP_4L23          = 4'h9,
    USP_LINK_L23_ENTR_L23       = 4'hA,
    USP_LINK_L23RDY             = 4'hB,
    USP_LINK_L23RDY_WAIT4ALIVE  = 4'hC
  } usp_link_fsm_state_e;



  typedef enum logic [2:0] {
    S_L1_U              = 3'h0,
    S_L1_0              = 3'h1,
    S_L1_0_WAIT4_ACK    = 3'h2,
    S_L1_0_WAIT4_CLKREQ = 3'h3,
    S_L1_N_ENTRY        = 3'h4,
    S_L1_N              = 3'h5,
    S_L1_N_EXIT         = 3'h6,
    S_L1_N_ABORT        = 3'h7
  } pm_l1sub_state_e;

  typedef enum logic [2:0] {
    PCLK_CHANGE_IDLE    = 3'h0, // pclk change idle state
    WAIT_CHANGEOK_RISE  = 3'h1, // wait for rising edge in phy_mac_pclkchangeok
    DRV_CLK_DIV         = 3'h2, // drive the change in pm_div_clock_ratio
    DRV_CHANGE_ACK      = 3'h3, // drive the change in mac_phy_pclkchangeack
    WAIT_CHANGEOK_FALL  = 3'h4  // wait for falling edge in phy_mac_pclkchangeok
  } pclk_change_fsm_state_e;

  // Downstream Port PM Protocol Negotiation FSM Encodings
  typedef enum logic [3:0] {
    DSP_PROT_RST               = 4'h0, // 
    DSP_PROT_RECOVERY          = 4'h1, // 
    DSP_PROT_ACTIVE            = 4'h2, // 
    DSP_PROT_RESPOND_NAK       = 4'h3, // 
    DSP_PROT_NAK_BLOCK_TLP     = 4'h4, // 
    DSP_PROT_WAIT_NAK_TLP_ACK  = 4'h5, // 
    DSP_PROT_WAIT_NAK_TIMER    = 4'h6, // 
    DSP_PROT_BLOCK_TLP         = 4'h7, // 
    DSP_PROT_WAIT_LAST_TLP_ACK = 4'h8, // 
    DSP_PROT_WAIT_LAST_PMDLLP  = 4'h9, // 
    DSP_PROT_ENTER_L1          = 4'hA, // 
    DSP_PROT_ENTER_L23         = 4'hB, // 
    DSP_PROT_ENTER_L0S         = 4'hC, // 
    DSP_PROT_WAIT_CXS_IDLE     = 4'hD  //
  } dsp_prot_fsm_state_e;

  // Downstream Physical Link Control FSM Encodings
  typedef enum logic [3:0] {
    DSP_LINK_RST               = 4'h0, // 
    DSP_LINK_RECOVERY          = 4'h1, // 
    DSP_LINK_L0                = 4'h2, // 
    DSP_LINK_ACK_WAIT4IDLE     = 4'h3, // 
    DSP_LINK_ENTR_L23          = 4'h4, // 
    DSP_LINK_L23RDY            = 4'h5, // 
    DSP_LINK_L23RDY_WAIT4ALIVE = 4'h6, // 
    DSP_LINK_ENTR_L1           = 4'h7, // 
    DSP_LINK_L1                = 4'h8, // 
    DSP_LINK_L1_EXIT           = 4'h9, // 
    DSP_LINK_ABORT             = 4'hA  // 
  } dsp_link_fsm_state_e;

  // L0s FSM Encodings
  typedef enum logic[2:0] {
    L0S_IDLE                   = 3'h0, // L0s idle state
    L0S_BLOCK_TLP              = 3'h1, // L0s block TLP
    L0S_ENTER_L0S              = 3'h2, // Enter L0s
    L0S_L0S                    = 3'h3, // L0s state
    L0S_EXIT                   = 3'h4  // L0s exit
  } pm_active_l0s_fsm_e;


// -----------------------------------------------------------------------------
// Parameter definitions
// -----------------------------------------------------------------------------

localparam NL          = `CX_NL;
localparam PWDN_WIDTH  = `CX_PHY_PDOWN_WD;
localparam PHY_RATE_WD = `CX_PHY_RATE_WD;
localparam RXSTATUS_WIDTH   = 3;
localparam [2:0] RX_PRESENT = 3'b011;
localparam RXSTATUS_WD      = 3;
localparam [`CX_PHY_PDOWN_WD - 1 : 0] P1_1  = `CX_PIPE43_P1_1_ENCODING;
localparam [`CX_PHY_PDOWN_WD - 1 : 0] P1_2  = `CX_PIPE43_P1_2_ENCODING;
localparam [`CX_PHY_PDOWN_WD - 1 : 0] P1CPM = `CX_PIPE43_P1CPM_ENCODING;
localparam [`CX_PHY_PDOWN_WD - 1 : 0] P0S  = {2'b00, `P0S};
localparam [`CX_PHY_PDOWN_WD - 1 : 0] P0   = {2'b00, `P0};
localparam [`CX_PHY_PDOWN_WD - 1 : 0] P1   = {2'b00, `P1};
localparam [`CX_PHY_PDOWN_WD - 1 : 0] P2   = {2'b00, `P2};
localparam [`CX_PHY_PDOWN_WD - 1 : 0] P2NOBEACON            = `CX_PIPE43_P2NOBEACON_ENCODING;
localparam                            P2NOBEACON_ENABLE_VAL = `CX_P2NOBEACON_ENABLE_VALUE;

// ----------------------------------------------------------------------------
// Interfacing between different PM modules
// ----------------------------------------------------------------------------
import cx_pl_pkg::dllp_struct;
import spif_pkg::state_enc_e;
import spif_pkg::protocol_cfg_t;

  localparam NF                   = `CX_NFUNC;            // number of functions
  localparam NVC                  = `CX_NVC;              // number of VCs
  //localparam NL                   = `CX_NL;
  localparam PHY_TXEI_WD          = `CX_PHY_TXEI_WD;

  // Structure containing signals from Protocol FSM to Link FSM
  typedef struct {
    logic                 software_entr_l1;     // Used in WAIT_DSTATE_UPDATE state (not applicable to Link FSM in SPIF mode)
    logic                 software_entr_l23;    // Used in WAIT_DSTATE_UPDATE state (not applicable to Link FSM in SPIF mode)
    logic                 latch_as_entr_l1;     // Used on WAIT_DSTATE_UPDATE transition (not applicable to Link FSM in SPIF mode)
    logic                 latched_entr_l23;
    logic                 prot_enter_l1;
    logic                 prot_enter_l23;
    logic                 lbc_active;           // Used in WAIT_DSTATE_UPDATE state (not applicable to Link FSM in SPIF mode)
    logic                 pm_timeout;           // Used in WAIT_DSTATE_UPDATE state (not applicable to Link FSM in SPIF mode)
    logic                 pm_smlh_entry_to_l0s;
    logic                 pm_smlh_l0s_exit;
    logic                 pm_smlh_dllp_hs;
    logic                 pm_linkst_in_l0s;
  } pm_protocol_to_link_struct;

  // Structure containing signals from Link FSM to Protocol FSM
  typedef struct {
    logic                 int_link_up_not_rcvry;
    logic                 int_idle_next;
    logic                 link_l1_finish;
    logic                 link_l23_finish;
    logic                 prot_to_active;
    logic                 usp_link_l1;
    logic                 usp_link_l0;
    logic                 usp_link_wait_dstate_update;
    logic                 pm_linkst_in_l1;
    logic                 pm_linkst_in_l2;
    logic                 pm_link_l23_flag_clear;
    logic                 pm_link_l23_restart_clear;
    logic                 pm_link_usp_l1_in_progress;
    logic                 pm_link_dsp_l1_in_progress;
    logic                 pm_link_block_all_tlp;
    logic                 pm_link_freeze_fc_timer;
    logic                 pm_link_hold_dllp_timer;
  } pm_link_to_protocol_struct;
// ----------------------------------------------------------------------------

endpackage // DWC_pcie_pm_pkg

`endif // __GUARD__DWC_PCIE_PM_PKG__SVH__
