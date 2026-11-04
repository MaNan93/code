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
// ---    $Revision: #62 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_ctrl.sv#62 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description: top level PM control logic
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
  `include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

 module pm_ctrl 
import DWC_pcie_ctl_pkg::xali_pkt_t;
import DWC_pcie_core_pkg::ltssm_state_e;
import DWC_pcie_core_pkg::pm_cdm_state_trans_track_t;
  import DWC_pcie_pm_pkg::P1_1;
  import DWC_pcie_pm_pkg::P1_2;
  import DWC_pcie_pm_pkg::P1CPM;
  import DWC_pcie_pm_pkg::P2NOBEACON;
  import DWC_pcie_pm_pkg::P2NOBEACON_ENABLE_VAL;
import DWC_pcie_pm_pkg::P0;
import DWC_pcie_pm_pkg::P1;
import DWC_pcie_pm_pkg::P2;
import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;

#(
// module parameter port list
   parameter INST   = 0  // The uniquifying parameter for each port logic instance.
)
(
// ---- inputs ---------------
    pm_usp_link_state,
    pm_dsp_link_state,
    pm_linkst_in_l0s,
    pm_linkst_in_l1,
    pm_linkst_in_l2,
    pm_linkst_in_l23rdy,
    pm_linkst_l2_exit,
    pm_linkst_in_l3,
    pm_xdlh_enter_l23,
    pm_prot_idle_flag,
    latch_as_entr_l1,
    lp_sdb_l1sub_aspm,
    lp_sdb_l1sub_pcipm,
    cfg_aspm_l1_timer_enable,
    cfg_upd_aslk_pmctrl,
    rstctl_ltssm_enable,
    link_req_rst_not,
    app_clk_req_n,
    phy_clk_req_n,
    app_hold_phy_rst,
    pipe_clk,
    aux_clk,
    pwr_rst_n,
    trgt_cpl_lut_empty,
    edma_xfer_pending,
    brdg_slv_xfer_pending,
    brdg_mstr_xfer_pending,
    radm_idle,
    upstream_port,
    switch_device,
    xdlh_xmt_pme_ack,
    one_dwsp_exit_l1,
    one_dwsp_exit_l23,
    app_ready_entr_l23,
    app_req_exit_l1,        
    xdlh_not_expecting_ack,
    smlh_link_up,
    smlh_in_l0,
    smlh_in_l1,
    smlh_in_l23,
    smlh_link_in_training,
    smlh_ltssm_state,
    sys_aux_pwr_det,
    cfg_aslk_pmctrl,
    cfg_clk_pm_en,
    all_dwsp_rcvd_toack_msg,
    outband_pwrup_cmd,
    cfg_upd_pmcsr,
    cfg_upd_aux_pm_en,
    cfg_upd_req_id,
    cfg_pmstatus_clr,
    cfg_pmstate,
    cfg_pme_en,
    cfg_aux_pm_en,
    cfg_pbus_num,
    cfg_pbus_dev_num,
    radm_pm_turnoff,
    radm_pm_to_ack,
    apps_pm_xmt_turnoff,
    apps_pm_xmt_pme,
    cfg_upd_pme_cap,
    cfg_pme_cap,
    current_data_rate,
    rmlh_descrambled_even_parity,
    xmlh_scramble_even_parity,
    aux_clk_active,
    cfg_l1sub_control,
    cfg_pl_l1sub_control,
    cfg_pl_l1_exit_mode,
    clkreq_in_n,
    cfg_pl_l1_clk_sel,
    cfg_p2nobeacon_enable,
    cfg_pipe_optional_pclkchange_hs,
    cfg_phy_perst_on_warm_reset,
    cfg_phy_rst_timer,
    cfg_pma_phy_rst_delay_timer,
    cfg_pl_aux_clk_freq,
    cfg_pl_gen3_zrxdc_noncompl,
    pme_to_ack_grt,
    lbc_active,
    pm_pme_grant,
    pme_turn_off_grt,
    perst_n,
    app_xfer_pending,
    slv_awvalid,
    slv_arvalid,
    slv_wvalid,
    brdg_dbi_xfer_pending,

  xali_xaim_pkt,

    app_obff_idle_msg_req,
    app_obff_obff_msg_req,
    app_obff_cpu_active_msg_req,

    cxl_cache_slv_req,
    pm_cxl_cache_slv_req,
    cxl_mem_slv_req,
    pm_cxl_mem_slv_req,
    cfg_phy_control,
    cfg_comm_clk_config,
    mac_phy_powerdown,
    mac_phy_txelecidle,
    app_sris_mode,
    xmlh_sris_enable,
    mac_phy_txdata,
    mac_phy_txdetectrx_loopback,
    mac_phy_txcompliance,
    mac_phy_rxpolarity,
    ltssm_rxpolarity,
    mac_phy_width,
    mac_phy_serdes_arch,
    mac_phy_rxwidth,
    serdes_pipe_rxready,
    serdes_pipe_turnoff_lanes,
    mac_phy_pclk_rate,
    mac_phy_rxstandby,
    mac_phy_rate,
    mac_phy_txdeemph,
    mac_phy_txdatavalid,
    mac_phy_rxeqeval,
    mac_phy_dirchange,
    mac_phy_smlh_coef_rtx,
    mac_phy_mbus,
    phy_mac_rxelecidle,
    phy_mac_phystatus,
    phy_mac_rxstatus,
    aux_sync_p1_ack,
    phystatus_pc_busy, // pulse converter busy flag
    core_rst_n,


    rx_lane_flip_en,
    tx_lane_flip_en,
    smlh_lane_flip_ctrl,

    cfg_link_dis,
    cfg_link_retrain,
    cfg_lpbk_en,
    cfg_2nd_reset,
    cfg_plreg_reset,
    app_init_rst,
    cfg_directed_speed_change,
    cfg_directed_width_change,
    ven_msg_req,
    ven_msi_req,
    app_ltr_msg_req,
    app_unlock_msg,
    msg_gen_unlock_grant,
    cfg_link_capable,
    app_l1sub_disable,
    latched_rxdetected,
    ptm_updating,
    phy_mac_pclkchangeok,
    phy_mac_maxpclkack_n,

    cfg_utility,
    pm_cfg_utility,
    cdm_pm_state_trans_tracker,
    smlh_pm_state_trans1_flag,
    smlh_pm_state_trans2_flag,

// ---- outputs ---------------
    pm_wake_req_exit_l0s,
    pm_l2_entry_flag,
    pm_wake_any_if_pending,
    lp_pcie_l1_exit,
    lp_pcie_clk_ack,
    lp_pcie_wake_req,
    pl_pcie_wake_ack,
    pl_pcie_clk_req,
    pl_pcie_phyinl1,
    pl_pcie_phyinl2,
    pl_pcie_state_l1,
    pl_pcie_state_l2,
    pl_pcie_state_active,
    pl_pcie_link_up,
    lp_cxl_l1_exit,
    lp_cxl_clk_ack,
    lp_cxl_wake_req,
    pl_cxl_wake_ack,
    pl_cxl_clk_req,
    pl_cxl_phyinl1,
    pl_cxl_phyinl2,
    pl_cxl_state_l1,
    pl_cxl_state_l2,
    pl_cxl_mode_enable,
    pm_hold_exit_l1,
    pm_link_exit_l1,
    pm_link_exit_l23,
    pm_pl_wake_ack,
    pm_pl_clk_req,
    pm_pl_phyinl1,
    pm_pl_phyinl2,
    pm_clk_pm_en,
    software_entr_l1,
    software_entr_l23,
    pm_aspm_l0s_en,
    pm_aspm_l1_en,
    pm_xtlh_block_tlp,
    pm_radm_block_tlp,
    wake,
    local_ref_clk_req_n,
    pm_smlh_l23_exit,
    pm_req_dwsp_turnoff,
    pm_xmt_turnoff,
    pm_xmt_to_ack,
    pm_xmt_pme,
    pm_turnoff_timeout,
    shadow_pm_usp_link_state,
    shadow_pm_dsp_link_state,
    shadow_pm_linkst_in_l0s,
    shadow_pm_linkst_in_l0,
    shadow_pm_l1_entry_started,
    shadow_pm_aspm_l1_enter_ready,
    pm_pme_en,
    pm_pme_en_split,
    pm_status,
    pm_aux_pm_en,
    pm_aux_pm_en_split,
    pm_bus_num,
    pm_dev_num,
    pm_curnt_state,
    pm_ltssm_enable,
    pm_current_data_rate,
    pm_rmlh_descrambled_even_parity,
    pm_xmlh_scramble_even_parity,
    pm_req_sticky_rst,
    pm_req_core_rst,
    pm_req_non_sticky_rst,
    pm_sel_aux_clk,
    pm_en_core_clk,
    pm_en_aux_clk_g,
    pm_req_phy_rst,
    pm_req_phy_perst,
    pm_upstream_port,
    pm_linkst_in_l1sub,
    pm_smlh_l1_2_latched,
    pm_smlh_l1_n_latched,
    pm_l1sub_state,
    pm_in_l11,
    pm_in_l12,
    pm_in_l1_short,
    pm_in_l1_cpm,
    pm_in_l1_abort,
    pm_pme_resend_flag,
    pm_block_phystatus,
    gasket_en_pulse_det,
    phy_if_cfg_phy_control,
    phy_if_cpcie_powerdown,
    phy_if_cpcie_txelecidle,
    phy_if_cpcie_asyncpowerchangeack,
    phy_if_cpcie_rxelecidle_disable,
    phy_if_cpcie_txcommonmode_disable,
    pm_io_handler_app_sris_mode,
    pm_io_handler_sris_enable,
    phy_if_cpcie_txdata,
    phy_if_cpcie_txdetectrx_loopback,
    phy_if_cpcie_txcompliance,
    phy_if_cpcie_rxpolarity,   
    phy_if_cpcie_width,
    phy_if_cpcie_serdes_arch,
    phy_if_cpcie_rxwidth,
    pm_serdes_pipe_rxready,
    pm_serdes_pipe_turnoff_lanes,
    phy_if_cpcie_pclk_rate,
    phy_if_cpcie_rxstandby,
    phy_if_cpcie_txdatavalid,
    phy_if_cpcie_rate,
    phy_if_cpcie_txdeemph,
    phy_if_cpcie_mbus,
    phy_if_cfg_comm_clk_config,
    phy_if_cpcie_rxeqeval,
    phy_if_cpcie_dirchange,
    phy_if_cpcie_smlh_coef_rtx,
    sqlchd_rxelecidle,
    pm_pmstate,
    pm_aux_clk_ft,
    pm_sys_aux_pwr_det_ft,
    pm_aux_clk_active_ft,
    pm_xadm_client0_tlp_hv
    ,
    pm_xadm_client1_tlp_hv
    ,
    pm_xadm_client2_tlp_hv

    ,
    pm_rx_lane_flip_ctrl,
    pm_tx_lane_flip_ctrl,
    pm_rx_pol_lane_flip_ctrl
    ,
    pm_init_rst,
    pm_unlock_msg_req
    ,
    pm_smlh_link_retrain
    ,
    pm_l1_entry_started,
    pm_l1_in_progress
    ,
    msg_gen_hv,
    lbc_cpl_hv
    ,
    pm_latched_rxdetected
    ,
    pm_powerdown_status,
    cfg_force_powerdown
    ,
    pm_div_max_pclk_ratio,
    mac_phy_pclkchangeack
    ,mac_phy_maxpclkreq_n
    ,pm_pclkack_timeout
    ,pm_aspm_l1_enter_ready
    
    ,pm_int_phy_powerdown
    ,pm_current_powerdown_p1
    ,pm_current_powerdown_p0

    ,pm_cdm_state_trans_tracking
);

input  usp_link_fsm_state_e        pm_usp_link_state;              // PM Link connections with PM CTRL
input  dsp_link_fsm_state_e        pm_dsp_link_state;              // PM Link connections with PM CTRL
input                   pm_linkst_in_l0s;                     // Signals from PM Link FSM
output                  pm_linkst_in_l1;
output                  pm_linkst_in_l2;
output                  pm_linkst_in_l23rdy;
output                  pm_linkst_l2_exit;
output                  pm_linkst_in_l3;
input                   pm_xdlh_enter_l23;                    // Signals from PM Protocol FSM
input                   pm_l1_entry_started;                  // Signals from PM Protocol FSM
input                   pm_l1_in_progress;                    // Signals from PM Protocol FSM
input                   pm_aspm_l1_enter_ready;               // Signals from PM Protocol FSM
input                   pm_prot_idle_flag;                    // Signals from PM Protocol FSM
input                   latch_as_entr_l1;                     // Signals from PM Protocol FSM
input                   lp_sdb_l1sub_aspm;                    // Signals from PM Protocol FSM
input                   lp_sdb_l1sub_pcipm;                   // Signals from PM Protocol FSM
input [(`CX_NFUNC - 1) : 0] cfg_upd_aslk_pmctrl;        // CDM update of Active state link pmctrl
input                   cfg_aspm_l1_timer_enable;       // CDM Control ASPM L1 Entry Timer
input                   rstctl_ltssm_enable;            // Application enables LTSSM
input                   link_req_rst_not;               // When set to 0 LTSSM requests reset due to surprise link down
input                   app_clk_req_n;                  // Application request ref clock removal
input                   phy_clk_req_n;                  // PHY acknowledge that it is ready for ref clock removal
input                   app_hold_phy_rst;               // Application requests to hold PHY reset
input                   trgt_cpl_lut_empty;             // TX PATH CPL LUT not empty
input                   edma_xfer_pending;
input                   brdg_mstr_xfer_pending;
input                   radm_idle;                      // Idle indication from the RADM
input                   brdg_slv_xfer_pending;
input                   aux_clk;                        // auxiliary clock
input                   pwr_rst_n;                      // power on reset
input                   pipe_clk;                       // PCLK for sampling Phystatus

input                   upstream_port;                  // upstream port
input                   switch_device;                  // Switch device
input                   xdlh_xmt_pme_ack;               // Txmt ACK PME

// for switch only
input                   all_dwsp_rcvd_toack_msg;        // All downstream ports received PM_TO_ACK message
input                   one_dwsp_exit_l1;               // One of the downstream ports exits L1
input                   one_dwsp_exit_l23;              // One of the downstream ports exits L23
// Config
input   [(`CX_NFUNC*2 - 1) :0]            cfg_aslk_pmctrl;                // Active Link PM enable
input   [`CX_NFUNC-1:0]                   cfg_upd_pmcsr;                  // PMCSR is written
input   [`CX_NFUNC-1:0]                   cfg_upd_aux_pm_en;              // AUX Power PM enable
input                                     cfg_upd_req_id;                 // update bus/dev/fun number, here 7:0 is set to support the max func number allowed in spec.
input   [`CX_NFUNC-1:0]        cfg_pmstatus_clr;               // PM status bits are cleared
input   [(3*`CX_NFUNC)-1:0]    cfg_pmstate;                    // PM state
input   [`CX_NFUNC-1:0]        cfg_pme_en;                     // PME_Enable
input   [(5*`CX_NFUNC)-1:0]    cfg_pme_cap;                    // PME Capability
input   [`CX_NFUNC-1:0]        cfg_upd_pme_cap;                // Update PME Capability field
input   [7:0]                  cfg_pbus_num;                   // Configured Primary bus number used to store for AUX power
input   [4:0]                  cfg_pbus_dev_num;               // Configured Device number used to store for AUX power
input   [`CX_NFUNC-1:0] cfg_aux_pm_en;                  // aux power pm enable
input                   cfg_clk_pm_en;                  // enables the clock request# signal to be deasserted at L1 and L23 state
input                   app_ready_entr_l23;             // inidcates that application is ready for L23 transition based on D3 programmed
 
input                   app_req_exit_l1;                // Provide a capability for applications to request PM state to exit L1. This is only effective when ASPM of L1 is enabled.

// from CXPL
input                   xdlh_not_expecting_ack;         // Transmiter has received all its ACKs for all transmitted TLPs

// handshake with Link state
input                   smlh_link_up;                   // link is up
input                   smlh_in_l0;                     // XMLH in l0
input                   smlh_in_l1;                     // XMLH in L1
input                   smlh_in_l23;                    // XMLH in L23 
input                   smlh_link_in_training;          // LTSSM is entering Recovery or Cfg
input ltssm_state_e     smlh_ltssm_state;               // LTSSM state
// from RADM
input                   radm_pm_turnoff;                // Received PM TURN OFF(only downstream port)
input                   radm_pm_to_ack;                 // Received PM TO ACK message (received by RC or downstream port)

// from Application side
input                   sys_aux_pwr_det;                 // AUX Power is detected
input                   apps_pm_xmt_turnoff;            // for switch application
input   [`CX_NFUNC-1:0] apps_pm_xmt_pme;                // for switch application
input   [`CX_NFUNC-1:0] outband_pwrup_cmd;              // out band power is up command such as WOL

input   [2:0]           current_data_rate;              // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4
input [`CX_NL-1:0]          rmlh_descrambled_even_parity;   // Current tx skip even data parity from RMLH
input [`CX_NL-1:0]          xmlh_scramble_even_parity;      // Current tx skip even data parity from XMLH
input                   aux_clk_active; // muxed aux clk has switched to low frequency clock, used when entering L1 to stall progression into L1 substates 
input  [`CX_L1SUB_CONTROL_WD-1:0] cfg_l1sub_control;   //L1 substates control signal bus
input  [`CX_PL_L1SUB_CONTROL_WD-1:0] cfg_pl_l1sub_control; //Port Logic L1 Substates control signal bus
input                   cfg_pl_l1_exit_mode; // Port logic bit to control L1 exit mode
input                   clkreq_in_n; // the state of the CLKREQ# pin, used for remotely initiated exit from L1 substates 
input                   cfg_pl_l1_clk_sel; // Port logic bit to select aux_clk source in L1
input                   cfg_p2nobeacon_enable; // Port logic bit to enable the support to P2.NoBeacon
input wire [31:0]       cfg_utility;           // Port Logic regsiter which is shadowed in pm_cfg block
output wire [31:0]      pm_cfg_utility;        // The utility shadow register is in turn shadowed in the port logic block
input                   cfg_pipe_optional_pclkchange_hs; // PIPE PCLK Change Optional Behaviour
input                   cfg_phy_perst_on_warm_reset; // PMC drive pm_req_phy_perst when warm reset
input [17:0]            cfg_phy_rst_timer;               // PHY RST timer
input [5:0]             cfg_pma_phy_rst_delay_timer;     // PMA reset to PIPE reset delay timer
input   [`CX_PL_AUX_CLK_FREQ_WD-1:0]  cfg_pl_aux_clk_freq;   // programmable auxiliary clock frequency
input                   cfg_pl_gen3_zrxdc_noncompl;  // Gen3 Zrx-dc noncompliance bit (8 GT/s Rx Impedance ECN).
input                   pme_to_ack_grt;              // PME Turnoff Ack request has been granted
input                   lbc_active;                  // The LBC may require a CPL to be sent, stop L1 timer
input   [`CX_NFUNC-1:0] pm_pme_grant;                // PM PME grant
input                   pme_turn_off_grt;            // PM Turn Off grant
input                   perst_n;
input                   app_xfer_pending;
// Power Gating exit conditions
input                           slv_awvalid;
input                           slv_arvalid;
input                           slv_wvalid;
input                 brdg_dbi_xfer_pending;

input xali_pkt_t[`N_XALI_IF-1:0] xali_xaim_pkt;

input                 msg_gen_hv;
input                 lbc_cpl_hv;

output wire [(2 * `CX_PHY_PDOWN_WD) - 1 : 0]  pm_powerdown_status;
input                                   cfg_force_powerdown;

input                 app_obff_idle_msg_req;
input                 app_obff_obff_msg_req;
input                 app_obff_cpu_active_msg_req;

input                 cxl_cache_slv_req;    // CXL.cache Slave Init request
output                pm_cxl_cache_slv_req; // Synchronized CXL.cache Slave Init request
input                 cxl_mem_slv_req;    // CXL.mem Slave Init request
output                pm_cxl_mem_slv_req; // Synchronized CXL.mem Slave Init request

input [31:0]                     cfg_phy_control;
input                            cfg_comm_clk_config;
input [(`CX_PHY_PDOWN_WD - 1) : 0]       mac_phy_powerdown;
input [(`CX_NL*`CX_PHY_TXEI_WD - 1) : 0] mac_phy_txelecidle;
input                            app_sris_mode;
input                            xmlh_sris_enable;
input [(`CX_PIPE_DATA_WD - 1) : 0]  mac_phy_txdata;
input [(`CX_NL - 1) : 0]            mac_phy_txdetectrx_loopback;
input [(`CX_NL - 1) : 0]            mac_phy_txcompliance;
input [(`CX_NL - 1) : 0]            mac_phy_rxpolarity;
input [(`CX_NL - 1) : 0]            ltssm_rxpolarity;
input [(`CX_PHY_WIDTH_WD -1) : 0]   mac_phy_width;
input                               mac_phy_serdes_arch;
input [(`CX_PHY_WIDTH_WD -1) : 0]   mac_phy_rxwidth;
input [(`CX_NL - 1) : 0]            serdes_pipe_rxready;
input [(`CX_NL - 1) : 0]            serdes_pipe_turnoff_lanes;
input [`PCLK_RATE_WD-1 : 0]         mac_phy_pclk_rate;
input [(`CX_NL - 1) : 0]            mac_phy_rxstandby;
input [(`CX_PHY_RATE_WD - 1) : 0]   mac_phy_rate;
input [(`CX_PHY_TXDEEMPH_WD - 1) : 0]      mac_phy_txdeemph;
input [(`CX_NL - 1) : 0]            mac_phy_txdatavalid;
input [(`CX_NL - 1) : 0]            mac_phy_rxeqeval;
input [(`CX_NL - 1) : 0]            mac_phy_dirchange;
input [(`CX_NL*`CX_TX_COEF_WD - 1) : 0] mac_phy_smlh_coef_rtx;
input [`CX_NL*8-1:0]                mac_phy_mbus;
input [(`CX_NL - 1) : 0]            phy_mac_phystatus;
input [((`CX_NL*3) - 1) : 0]        phy_mac_rxstatus;
input   [`CX_NL-1:0]                phy_mac_rxelecidle;             // PHY is in EIDLE
input [1:0]                     aux_sync_p1_ack;
input [1:0]                     phystatus_pc_busy;
input                           core_rst_n;             // Core reset
input                           rx_lane_flip_en; // Lane flip control
input                           tx_lane_flip_en; // Lane flip control
input [`CX_L2NL-1:0]            smlh_lane_flip_ctrl; // Lane flip control

input                           cfg_link_dis; // disable the link
input                           cfg_link_retrain; // link retrain request
input                           cfg_lpbk_en; // loopback enable request
input                           cfg_2nd_reset; // secondary reset
input                           cfg_plreg_reset; // port logic secondary reset
input                           app_init_rst; // application request hot reset
input                           cfg_directed_speed_change; // directed speed change
input                           cfg_directed_width_change; // directed width change
input                           ven_msg_req; // vendor message request
input                           ven_msi_req; // vendor msi message request
input                           app_ltr_msg_req; // LTR message request
input                           app_unlock_msg; // Unlock message request
input                           msg_gen_unlock_grant; // msg_gen grants unlock message
input                           app_l1sub_disable;               // Gate the L1 sub-states control bits
input                           ptm_updating; //PTM Update is in progress
input [5:0]                     cfg_link_capable; // PL LINK_CAPABLE register, indicate used lanes at reset
input [`CX_NL-1:0]               latched_rxdetected;        // Level : PIPE: Detect Lane for Ras D.E.S Silicon Debug

input [4:0]                        cdm_pm_state_trans_tracker;
input                              smlh_pm_state_trans1_flag;
input                              smlh_pm_state_trans2_flag;

// ------------- Outputs ---------------
output                    pm_hold_exit_l1;              // PM Active Controller instructs PM Link FSM to hold L1 exit
output                    pm_link_exit_l1;              // PM Active Controller instructs PM Link FSM to exit L1
output                    pm_link_exit_l23;             // PM Active Controller instructs PM Link FSM to exit L23
output                    pm_pl_wake_ack;               // PM Active Controller Wakeup Acknowledge
output                    pm_pl_clk_req;                // PM Active Controller Clock Request
output                    pm_pl_phyinl1;                // PM Active Controller PHY in L1
output                    pm_pl_phyinl2;                // PM Active Controller PHY in L2
output                    pm_clk_pm_en;                 // Output to PM Link FSM
output                    software_entr_l1;             // PME Controller instructs PM Protocol FSM to start L1
output                    software_entr_l23;            // PME Controller instructs PM Protocol FSM to start L1
output                    pm_aspm_l0s_en;               // PME Controller indicates to the PM Protocol FSM that L0s ASPM is enabled
output                    pm_aspm_l1_en;                // PME Controller indicates to the PM Protocol FSM that L1 ASPM is enabled
output                    pm_xtlh_block_tlp;            // Instructs XTLH to block any new TLPs
output  [`CX_NFUNC-1:0]   pm_radm_block_tlp;            // Instructs RADM receive filter to reject TLPs other than CFG/MSG
output                    pm_wake_req_exit_l0s;         // Output to PM Protocol FSM
output                    pm_l2_entry_flag;             // Output to PM Protocol FSM
output                    pm_wake_any_if_pending;       // Output to PM Protocol FSM
output                    lp_pcie_l1_exit;              // SPIF: Request to PCIe/CXL.io Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
output                    lp_pcie_clk_ack;              // SPIF: PCIe/CXL.io Link Layer acknowledges LogPHY request to remove the clock gating
output                    lp_pcie_wake_req;             // SPIF: PCIe/CXL.io Link Layer requests LogPHY to remove the clock gating
input                     pl_pcie_wake_ack;             // SPIF: LogPHY acknowledges lp_wake_req to PCIe/CXL.io Link Layer
input                     pl_pcie_clk_req;              // SPIF: LogPHY requests PCIe/CXL.io Link Layer to remove the clock gating
input                     pl_pcie_phyinl1;              // SPIF: LogPHY indication on PCIe/CXL.io SPIF interface that PHY is in L1 state
input                     pl_pcie_phyinl2;              // SPIF: LogPHY indication on PCIe/CXL.io SPIF interface that PHY is in L2 state
input                     pl_pcie_state_l1;             // SPIF: pl_state_sts is in IDLE_L1_1 on PCIe/CXL.io SPIF interface
input                     pl_pcie_state_l2;             // SPIF: pl_state_sts is in L2 on PCIe/CXL.io SPIF interface
input                     pl_pcie_state_active;         // SPIF: pl_state_sts is in ACTIVE or ACTIVE_L0S_PMNAK on PCIe/CXL.io SPIF interface
input                     pl_pcie_link_up;              // SPIF: pl_link_up on PCIe/CXL.io SPIF interface
output                    lp_cxl_l1_exit;               // SPIF: Request to CXL.cachemem Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
output                    lp_cxl_clk_ack;               // SPIF: CXL.cachemem Link Layer acknowledges LogPHY request to remove the clock gating
output                    lp_cxl_wake_req;              // SPIF: CXL.cachemem Link Layer requests LogPHY to remove the clock gating
input                     pl_cxl_wake_ack;              // SPIF: LogPHY acknowledges lp_wake_req to CXL.cachemem Link Layer
input                     pl_cxl_clk_req;               // SPIF: LogPHY requests CXL.cachemem Link Layer to remove the clock gating
input                     pl_cxl_phyinl1;               // SPIF: LogPHY indication on CXL.cachemem SPIF interface that PHY is in L1 state
input                     pl_cxl_phyinl2;               // SPIF: LogPHY indication on CXL.cachemem SPIF interface that PHY is in L2 state
input                     pl_cxl_state_l1;              // SPIF: pl_state_sts is in IDLE_L1_1 on CXL.cachemem SPIF interface
input                     pl_cxl_state_l2;              // SPIF: pl_state_sts is in L2 on CXL.cachemem SPIF interface
input                     pl_cxl_mode_enable;           // SPIF: SPLH Configuration - CXL Mode Enable bit


output                    wake;                         // indicate application to wakeup from l2
output                    local_ref_clk_req_n;                      // indicates to PHY the states that required clock. When it inidcates not required clock, it is imporatant to make sure that PHY is specially designed for this.

// to CXPL
input                     pm_smlh_l23_exit;               // PMC directs XMLH L23 EXIT
// to CDM
output                    pm_xmt_turnoff;                 // to send TURNOFF MSG TLP (only for downstream)
output                    pm_turnoff_timeout;             // Indicates to application of RC or downstream port of a swtich that PM turnoff timeout has occurred
output  [`CX_NFUNC-1:0]   pm_xmt_to_ack;                  // to send PM_TO_ACK TLP (only for upstream port)
output  [`CX_NFUNC-1:0]   pm_xmt_pme;                     // to send PM_PME TLP
output  [`CX_NFUNC-1:0]   pm_status;                      // PM status register
output  [`CX_NFUNC-1:0]   pm_pme_en;                      // PM PME_EN register
output  [`CX_NFUNC-1:0]   pm_pme_en_split;                // PM PME_EN register to be fed back internally in the core
output  [`CX_NFUNC-1:0]   pm_aux_pm_en;                   // AUX PM EN register
output  [`CX_NFUNC-1:0]   pm_aux_pm_en_split;             // AUX PM EN split port
output  [`CX_BUSNUM_WD -1:0]  pm_bus_num;
output  [`CX_DEVNUM_WD -1:0]  pm_dev_num;

// for switch only
output                    pm_req_dwsp_turnoff;
output  usp_link_fsm_state_e       shadow_pm_usp_link_state;       // PM CTRL connections with CDM
output  dsp_link_fsm_state_e       shadow_pm_dsp_link_state;       // PM CTRL connections with CDM
output                    shadow_pm_linkst_in_l0s;
output                    shadow_pm_linkst_in_l0;

output  [2:0]           pm_curnt_state;                 // PM current state
output                  pm_linkst_in_l1sub; // link state has entered L1 PM substates - used in clk_rst to keep AUX clock switched to free running clock
output                  pm_smlh_l1_2_latched; // 1: L1_SUB entered L1_2 substate
output                  pm_smlh_l1_n_latched; // 1: L1_SUB entered L1_N substate
output [2:0]            pm_l1sub_state;    // L1 sub state
output                  pm_in_l11;      // L1.1 Entry
output                  pm_in_l12;      // L1.2 Entry
output                  pm_in_l1_short; // L1 short duration
output                  pm_in_l1_cpm;   // L1 Clock PM (L1 with REFCLK removal/PLL Off)
output                  pm_in_l1_abort; // L1.2 abort
output                  pm_pme_resend_flag;
output                  pm_req_sticky_rst;
output                  pm_req_core_rst;
output                  pm_req_non_sticky_rst;
output                  pm_req_phy_rst;
output                  pm_req_phy_perst;
output                  pm_upstream_port;
output                  pm_ltssm_enable; // The application enable for the LTSSM shadowed in the always on domain
output  [2:0]           pm_current_data_rate;   // Current data rate shadowed in the always on domain
output [`CX_NL-1:0]     pm_rmlh_descrambled_even_parity;   // Current rx skip even data parity shadowed in always on domain
output [`CX_NL-1:0]     pm_xmlh_scramble_even_parity;      // Current tx skip even data parity shadowed in always on domain
output                  pm_sel_aux_clk; // Select the slow clock for aux_clk
output                  pm_en_core_clk; // enable the core_clk
output                  pm_en_aux_clk_g; // Enable the gate aux clock that is used for CDM

output                              pm_block_phystatus;
output [1:0]                        gasket_en_pulse_det;
output                              phy_if_cpcie_asyncpowerchangeack;
output                              phy_if_cpcie_rxelecidle_disable;
output                              phy_if_cpcie_txcommonmode_disable;
output  [31:0]                              phy_if_cfg_phy_control;
output  [(`CX_PHY_PDOWN_WD - 1) : 0]        phy_if_cpcie_powerdown;
output  [(`CX_NL*`CX_PHY_TXEI_WD - 1) : 0]  phy_if_cpcie_txelecidle;
output                              pm_io_handler_app_sris_mode;
output                              pm_io_handler_sris_enable;
output  [(`CX_PIPE_DATA_WD - 1) : 0]    phy_if_cpcie_txdata;
output  [(`CX_NL - 1) : 0]              phy_if_cpcie_txdetectrx_loopback;
output  [(`CX_NL - 1) : 0]              phy_if_cpcie_txcompliance;
output  [(`CX_NL - 1) : 0]              phy_if_cpcie_rxpolarity;
output  [(`CX_PHY_WIDTH_WD -1) : 0]     phy_if_cpcie_width;
output                                  phy_if_cpcie_serdes_arch;
output  [(`CX_PHY_WIDTH_WD -1) : 0]     phy_if_cpcie_rxwidth;
output  [(`CX_NL -1) : 0]               pm_serdes_pipe_rxready;
output  [(`CX_NL -1) : 0]               pm_serdes_pipe_turnoff_lanes;
output  [`PCLK_RATE_WD-1 : 0]       phy_if_cpcie_pclk_rate;
output  [(`CX_NL - 1) : 0]          phy_if_cpcie_rxstandby;
output  [(`CX_NL - 1) : 0]          phy_if_cpcie_txdatavalid;
output  [(`CX_PHY_RATE_WD - 1) : 0] phy_if_cpcie_rate;
output  [(`CX_PHY_TXDEEMPH_WD - 1) : 0]    phy_if_cpcie_txdeemph;
output  [`CX_NL*8-1:0]              phy_if_cpcie_mbus;
output                              phy_if_cfg_comm_clk_config;
output  [(`CX_NL - 1) : 0]          phy_if_cpcie_rxeqeval;
output  [(`CX_NL - 1) : 0]          phy_if_cpcie_dirchange;
output  [(`CX_NL*`CX_TX_COEF_WD - 1) : 0]phy_if_cpcie_smlh_coef_rtx;
output  [(`CX_NL - 1) : 0]          sqlchd_rxelecidle;
output  [((3*`CX_NFUNC) - 1) : 0]   pm_pmstate;
output                              pm_aux_clk_ft; // Aux clock fed through pm_ctrl
output                              pm_sys_aux_pwr_det_ft; // sys_aux_pwr_det fed through pm_ctrl
output                              pm_aux_clk_active_ft; // aux_clk_active fed through pm_ctrl
output [`CX_NVC_XALI_EXPANSION-1:0] pm_xadm_client0_tlp_hv; // client0_tlp_hv fed through pm_ctrl
output [`CX_NVC_XALI_EXPANSION-1:0] pm_xadm_client1_tlp_hv; // client1_tlp_hv fed through pm_ctrl
output [`CX_NVC_XALI_EXPANSION-1:0] pm_xadm_client2_tlp_hv; // client2_tlp_hv fed through pm_ctrl
output                              pm_init_rst; // pm hot reset request
output                              pm_unlock_msg_req; // pm unlock message request
output              pm_smlh_link_retrain;
output              shadow_pm_l1_entry_started; // L1 entry process started


output [`CX_L2NL - 1 : 0]          pm_rx_lane_flip_ctrl;
output [`CX_L2NL - 1 : 0]          pm_tx_lane_flip_ctrl;
output [`CX_L2NL - 1 : 0]          pm_rx_pol_lane_flip_ctrl;

input  [`CX_NL-1:0]                phy_mac_pclkchangeok;
output [`CX_NL-1:0]                mac_phy_pclkchangeack;
output [6:0]                       pm_div_max_pclk_ratio;
wire                               pclk_hs_rst;
output                             mac_phy_maxpclkreq_n;
input                              phy_mac_maxpclkack_n;
output                             pm_pclkack_timeout;
output [`CX_NL-1:0]                pm_latched_rxdetected;
output  [(`CX_PHY_PDOWN_WD - 1) : 0]  pm_int_phy_powerdown;   // PM PHY powerdown 2 LSB's for freq_step and pipe_loopback 
output                             pm_current_powerdown_p1;
output                             pm_current_powerdown_p0;

output                             shadow_pm_aspm_l1_enter_ready;


output pm_cdm_state_trans_track_t  pm_cdm_state_trans_tracking;


//
// -----------------------------------------------------------------------
wire              pm_current_powerdown_p2;
wire              pmu_l2_pd;
wire              shadow_pm_l1_in_progress;                    // Signals from PM Protocol FSM
wire              shadow_latch_as_entr_l1;                     // Signals from PM Protocol FSM
wire              shadow_pl_pcie_phyinl1;
wire              shadow_pl_pcie_phyinl2;
wire              shadow_pl_pcie_state_l1;
wire              shadow_pl_pcie_state_l2;
wire              shadow_pl_pcie_state_active;
wire              shadow_pl_pcie_link_up;
wire              shadow_pl_cxl_phyinl1;
wire              shadow_pl_cxl_phyinl2;
wire              shadow_pl_cxl_state_l1;
wire              shadow_pl_cxl_state_l2;
wire              shadow_pl_cxl_mode_enable;
wire              shadow_lp_sdb_l1sub_aspm;                    // Signals from PM Protocol FSM
wire              shadow_lp_sdb_l1sub_pcipm;                   // Signals from PM Protocol FSM
wire              shadow_pm_xdlh_enter_l23;
wire              pm_linkst_sel_aux_clk;
wire              pm_linkst_en_core_clk;
wire              pm_l1sub_sel_aux_clk;
wire              pm_l1_cpm_exit;
wire              pm_smlh_link_retrain;

wire              phy_mac_gk_pclkack_n;
wire [1 : 0]      cfg_trgt_l1sub;
wire              cfg_trgt_l1cpm;
wire              pm_req_exit_p2;
wire              l1sub_state_is_l1_u;
wire              phy_mac_pclkack_n;

wire            pm_l1sub_pg_enable;
wire            pm_l1sub_pg_disable;
wire            pm_clkreq_in_n;
wire            gasket_rxelecidle_disable;
wire            gasket_txcommonmode_disable;
wire            gasket_pg_ack;
wire            pm_l1sub_l11_next;
wire            pm_l1sub_l12_next;
wire            pm_l1sub_req_p1cpm;
wire            pm_l1sub_abort_next;
wire            pm_l1sub_clk_req_n;
wire                                   phy_if_cpcie_asyncpowerchangeack; //from gasket
wire                                   phy_if_cpcie_rxelecidle_disable;
wire                                   phy_if_cpcie_txcommonmode_disable;
wire [31:0]                            phy_if_cfg_phy_control;
wire [(`CX_PHY_PDOWN_WD - 1) : 0]      int_cpcie_powerdown;
wire [(`CX_NL*`CX_PHY_TXEI_WD - 1) : 0]int_cpcie_txelecidle;
wire [(`CX_PHY_PDOWN_WD - 1) : 0]      phy_if_cpcie_powerdown;
wire [(`CX_PHY_PDOWN_WD - 1) : 0]      phy_if_cpcie_pm_powerdown; //from pm_active
wire [(`CX_PHY_PDOWN_WD - 1) : 0]      phy_if_cpcie_gk_powerdown; //from gasket
wire [(`CX_NL*`CX_PHY_TXEI_WD - 1) : 0]phy_if_cpcie_txelecidle;
wire                             pm_io_handler_app_sris_mode;
wire                             pm_io_handler_sris_enable;
wire [(`CX_PIPE_DATA_WD - 1) : 0]phy_if_cpcie_txdata;
wire [(`CX_NL - 1) : 0]          phy_if_cpcie_txdetectrx_loopback;
wire [(`CX_NL - 1) : 0]          phy_if_cpcie_txcompliance;
wire [(`CX_NL - 1) : 0]          phy_if_cpcie_rxpolarity;
wire [(`CX_PHY_WIDTH_WD -1) : 0] phy_if_cpcie_width;
wire                             phy_if_cpcie_serdes_arch;
wire [(`CX_PHY_WIDTH_WD -1) : 0] phy_if_cpcie_rxwidth;
wire [(`CX_NL - 1) : 0]          pm_serdes_pipe_rxready;
wire [`PCLK_RATE_WD-1 : 0]       phy_if_cpcie_pclk_rate;
wire [(`CX_NL - 1) : 0]          phy_if_cpcie_rxstandby;
wire [(`CX_NL - 1) : 0]          phy_if_cpcie_txdatavalid;
wire [(`CX_PHY_RATE_WD - 1) : 0] phy_if_cpcie_rate;
wire [(`CX_PHY_TXDEEMPH_WD - 1) : 0]    phy_if_cpcie_txdeemph;
wire                             phy_if_cpcie_blockaligncontrol;
wire [`CX_NL*8-1:0]              phy_if_cpcie_mbus;
wire [(`CX_NL - 1) : 0]          phy_if_cpcie_rxeqeval;
wire [(`CX_NL - 1) : 0]          phy_if_cpcie_dirchange;
wire [(`CX_NL*`CX_TX_COEF_WD - 1) : 0]phy_if_cpcie_smlh_coef_rtx;
wire  [(`CX_NL - 1) : 0]                sqlchd_rxelecidle;
wire  [(`CX_NL - 1) : 0]                int_pm_rxelecidle;


wire                    pm_en_aux_clk_g;
wire                    pm_sync_perst_n; // perst_n synchronized to aux_clk
wire                    pm_core_rst_done;
wire                    pm_det_l2; // core is in L2 state with main power removed
wire                    pre_pm_exit_p2; // one cycle before p2 exit
wire                    pm_phy_rxelecidle_disable;
wire                    pm_phy_txcommonmode_disable;

wire                    shadow_pm_linkst_in_l0s;
wire                    pm_linkst_in_l0;
wire                    pm_linkst_in_l23rdy;

wire                    pm_wake_l2_exit;
wire                    pm_smlh_entry_to_l0s;
wire                    shadow_pm_prot_idle_flag;
wire    [2:0]           pm_curnt_state;
wire                    pm_pme_exit_l1;

wire                    local_ref_clk_req_n;
wire                    pm_req_sticky_rst;
wire                    pm_req_core_rst;
wire                    pm_req_phy_rst;
wire                    pm_req_phy_perst;
wire                    pm_req_non_sticky_rst;
wire                    pm_upstream_port;
wire                    pm_set_phy_p1;
wire                    pm_phy_rst_done; // PHY out of reset after exit from L2
wire                    pm_perst_powerdown;

wire                    shadow_smlh_link_up;
wire                    pm_ltssm_enable;
wire    [2:0]           pm_current_data_rate;   // Current data rate shadowed in the always on domain
wire                    pm_sel_aux_clk;
wire                    pm_en_core_clk;

wire                    pmu_sel_aux_clk;
wire                    pm_wake_dbi_pending;
wire                    pm_wake_block_pg;
wire                    pm_wake_l1_pg_ack;
wire                    pm_wake_l1_pg_exit;
wire  [(`CX_NFUNC*2 - 1) : 0]           pm_aslk_pmctrl;
wire  [(`CX_NFUNC - 1) : 0]             pm_aux_pm_en;
wire  [(`CX_NFUNC - 1) : 0]             pm_aux_pm_en_split;
wire  [(`CX_NFUNC - 1) : 0]             pm_pme_en;
wire  [(`CX_NFUNC - 1) : 0]             pm_pme_en_split;
wire  [(`CX_BUSNUM_WD - 1) : 0]         pm_bus_num;
wire  [(`CX_DEVNUM_WD - 1) : 0]         pm_dev_num;
wire  [((5*`CX_NFUNC) - 1) : 0]         pm_pme_cap;
wire  [((3*`CX_NFUNC) - 1) : 0]         pm_pmstate;
wire  [(`CX_L1SUB_CONTROL_WD - 1) : 0]   pm_l1sub_control;
wire  [(`CX_PL_L1SUB_CONTROL_WD - 1) : 0]pm_pl_l1sub_control;
wire                                     pm_pl_l1_exit_mode;
wire                                     pm_pl_l1_clk_sel;
wire  [(`CX_PL_AUX_CLK_FREQ_WD - 1) : 0] pm_pl_aux_clk_freq;
wire [(`CX_PHY_PDOWN_WD - 1) : 0]        pm_cfg_phy_powerdown_p2_options;
wire                                    pm_pl_gen3_zrxdc_noncompl;
wire                                    gasket_drive_pd;
wire                                    gasket_drive_pd_no_clk;
wire                                    pm_block_phystatus;
wire [1:0]                              gasket_en_pulse_det;
wire                                    pm_aux_clk_ft;
wire                                    pm_sys_aux_pwr_det_ft;
wire                                    pm_aux_clk_active_ft;
wire [`CX_NVC_XALI_EXPANSION-1:0]       pm_xadm_client0_tlp_hv; // client0_tlp_hv fed through pm_ctrl
wire [`CX_NVC_XALI_EXPANSION-1:0]       pm_xadm_client1_tlp_hv; // client1_tlp_hv fed through pm_ctrl
wire [`CX_NVC_XALI_EXPANSION-1:0]       pm_xadm_client2_tlp_hv; // client2_tlp_hv fed through pm_ctrl

wire [`CX_L2NL - 1 : 0]                 pm_rx_lane_flip_ctrl;
wire [`CX_L2NL - 1 : 0]                 pm_tx_lane_flip_ctrl;
wire [`CX_L2NL - 1 : 0]                 pm_rx_pol_lane_flip_ctrl;
wire pm_rst_sel_aux_clk;

wire                                    pm_init_rst; // pm hot reset request
wire                                    pm_unlock_msg_req; // pm unlock message request
wire [1:0]  int_cfg_trgt_l1sub;
wire        int_cfg_trgt_l1cpm;

wire [`CX_NL-1:0]                       pm_lane_active; // the active lanes


wire [5:0]                              pm_link_capable; 
wire [17:0]                             pm_phy_rst_timer;
wire [5:0]                              pm_pma_phy_rst_delay_timer;
wire                                    pm_l1sub_fsm_rst;
wire                                    phystatus_pclk_ready;
wire                                    phystatus_if_sel_aux_clk;
wire                                    perst_n_posedge;
wire [4:0]                              pm_cdm_pm_state_trans_tracker;
wire                                    pm_smlh_pm_state_trans1_flag;
wire                                    pm_smlh_pm_state_trans2_flag;
wire                                    phy_if_cpcie_xmlh_sris_enable;
wire                                    pm_clk_ack;             // PM Link Controller: Link Layer acknowledges pm_clk_req
wire                                    pm_clk_req;             // PM Active Controller: LogPHY request to remove Link Layer clock gating
wire                                    pm_phyinl1;             // PM Active Controller: PM is in L1 and current power down state is P1
wire                                    pm_phyinl2;             // PM Active Controller: PM is in L2 and current power down state is P2
wire                                    pm_en_core_clk_gating;  // PM Active Controller: Enable core_clk gating when LogPHY is enabled
wire                                    pm_wake_req;
wire                                    pm_wake_ack;
wire                                    pm_wakeup_event;

wire [`CX_NL-1:0]   phy_mac_rxelecidle_int;
wire [`CX_NL-1:0]   phy_mac_phystatus_int;
wire [`CX_NL*3-1:0] phy_mac_rxstatus_int;
assign phy_mac_rxelecidle_int  = phy_mac_rxelecidle;
assign phy_mac_phystatus_int   = phy_mac_phystatus;
assign phy_mac_rxstatus_int    = phy_mac_rxstatus;

// ----------------------------------------------------------------------------
// PM clock control
// ----------------------------------------------------------------------------
pm_clk_control
 u_pm_clk_control(
  // Inputs
  .aux_clk                    (aux_clk),
  .pwr_rst_n                  (pwr_rst_n),
  .aux_clk_active             (aux_clk_active),
  .pm_rst_sel_aux_clk         (pm_rst_sel_aux_clk),
  .pm_linkst_sel_aux_clk      (pm_linkst_sel_aux_clk),
  .pm_linkst_en_core_clk      (pm_linkst_en_core_clk),
  .pm_l1sub_sel_aux_clk       (pm_l1sub_sel_aux_clk),
  .pm_drive_pd                (gasket_drive_pd),
  .phystatus_if_sel_aux_clk   (phystatus_if_sel_aux_clk),
  .gasket_maxpclk_removed     (gasket_maxpclk_removed),
  // Outputs
  .pm_clk_sel_aux_clk         (pm_sel_aux_clk),
  .pm_clk_en_core_clk         (pm_en_core_clk),
  .pm_clk_aux_clk_active      (pm_aux_clk_active)
  ,.pm_clk_aux_clk_inactive   (pm_aux_clk_inactive)
);

wire  gasket_powerdown_p1_2;
assign phy_if_cpcie_powerdown           = phy_if_cpcie_gk_powerdown;
assign gasket_powerdown_p1_2 = (phy_if_cpcie_gk_powerdown == P1_2) && gasket_txcommonmode_disable;

assign int_cfg_trgt_l1sub =  cfg_trgt_l1sub;
assign int_cfg_trgt_l1cpm = cfg_trgt_l1cpm;

gasket_ctrl
 #(
.PDWN_WIDTH       (`CX_PHY_PDOWN_WD),
.P0               (P0),
.P1               (P1),
.P2               (P2),
.P1_1             (P1_1),
.P1_2             (P1_2),
.P1CPM            (P1CPM)
) u_gasket_ctrl (
//--------------------- Inputs -----------------------
    .phystatus                      (phy_mac_phystatus_int),
    .aux_sync_p1_ack                (aux_sync_p1_ack),
    .phystatus_pc_busy              (phystatus_pc_busy),
    .aux_clk                        (aux_clk),
    .pwr_rst_n                      (pwr_rst_n),
    .pm_powerdown                   (phy_if_cpcie_pm_powerdown),
    .pm_linkst_in_l1                (pm_linkst_in_l1),
    .smlh_in_l1                     (smlh_in_l1),
    .pm_req_exit_l1                 (pm_l1_cpm_exit),
    .pm_lane_active                 (pm_lane_active),
    .l1sub_exit                     (pm_l1sub_pg_disable), // exit L1 PM Substate
    .cfg_trgt_l1sub                 (int_cfg_trgt_l1sub),
    .l1sub_l11_next                 (pm_l1sub_l11_next),
    .l1sub_l12_next                 (pm_l1sub_l12_next),
    .l1sub_l1_u_next                (l1sub_state_is_l1_u),
    .l1sub_abort_next               (pm_l1sub_abort_next),
    .cfg_pl_l1sub_fast_exit         (pm_pl_l1sub_control[(`CX_PL_L1SUB_CONTROL_WD - 1)]),
    .l1sub_req_p1cpm                (pm_l1sub_req_p1cpm),
    .pm_l1sub_clk_req_n             (pm_l1sub_clk_req_n),
    .cfg_trgt_l1cpm                 (int_cfg_trgt_l1cpm),
    .pm_linkst_l23rdy               (pm_linkst_in_l23rdy),
    .pm_req_exit_p2                 (pm_req_exit_p2),
    .pm_cfg_phy_powerdown_p2_options (pm_cfg_phy_powerdown_p2_options),
    .perst_n                        (pm_sync_perst_n),
    .phystatus_done_auxclk          (phystatus_done_aux_clk),
    .aux_clk_active                 (aux_clk_active),
    .phy_mac_maxpclkack_n           (phy_mac_maxpclkack_n),
    .pm_perst_powerdown             (pm_perst_powerdown),
//--------------------- Outputs -----------------------
    .pclkack_n                      (phy_mac_gk_pclkack_n),
    .pclkreq_n                      (gasket_clk_req_n),
    .asyncpowerchangeack            (phy_if_cpcie_asyncpowerchangeack),
    .gasket_pg_ack                  (gasket_pg_ack),
    .gasket_rxelecidle_disable      (gasket_rxelecidle_disable),
    .gasket_txcommonmode_disable    (gasket_txcommonmode_disable),
    .powerdown                      (phy_if_cpcie_gk_powerdown),
    .gasket_drive_pd                (gasket_drive_pd),
    .gasket_drive_pd_no_clk         (gasket_drive_pd_no_clk),
    .gasket_block_phystatus         (pm_block_phystatus),
    .gasket_en_pulse_det            (gasket_en_pulse_det),
    .gasket_sel_aux_clk             (gasket_sel_aux_clk)
    ,
    .mac_phy_maxpclkreq_n           (mac_phy_maxpclkreq_n),
    .gasket_maxpclk_removed         (gasket_maxpclk_removed),
    .gasket_maxpclk_back_on         (gasket_maxpclk_back_on)
); // gasket_ctrl


//
// PCI link PM state control
//

pme_ctrl
 
#(INST) u_pme_ctrl(
//--------------------- Inputs -----------------------
    .aux_clk                        (aux_clk),
    .pwr_rst_n                      (pwr_rst_n),
    .pm_core_rst_done               (pm_core_rst_done),
    .perst_n                        (pm_sync_perst_n),
    .switch_device                  (switch_device),
    .upstream_port                  (pm_upstream_port),
    .all_dwsp_rcvd_toack_msg        (all_dwsp_rcvd_toack_msg),
    .pm_pme_cap                     (pm_pme_cap),
    .apps_pm_xmt_turnoff            (apps_pm_xmt_turnoff),
    .apps_pm_xmt_pme                (apps_pm_xmt_pme),
    .app_ready_entr_l23             (app_ready_entr_l23),
    .one_dwsp_exit_l23              (one_dwsp_exit_l23),
    .nhp_pme_det                    ({`CX_NFUNC{1'b0}}),
    .radm_pm_turnoff                (radm_pm_turnoff),
    .radm_pm_to_ack                 (radm_pm_to_ack ),
    .outband_pwrup_cmd              (outband_pwrup_cmd),
    .xdlh_xmt_pme_ack               (xdlh_xmt_pme_ack),
    .cfg_pmstatus_clr               (cfg_pmstatus_clr),
    .pm_pme_en                      (pm_pme_en),
    .pl_state_active                (shadow_pl_pcie_state_active),
    .pl_link_up                     (shadow_pl_pcie_link_up),
    .pm_prot_idle_flag              (shadow_pm_prot_idle_flag),
    .pm_smlh_l23_exit               (pm_smlh_l23_exit),
    .pm_xdlh_enter_l23              (shadow_pm_xdlh_enter_l23),
    .current_data_rate              (pm_current_data_rate),
    .pme_to_ack_grt                 (pme_to_ack_grt),
    .pm_pme_grant                   (pm_pme_grant),
    .pme_turn_off_grt               (pme_turn_off_grt),
    .aux_clk_active                 (pm_aux_clk_active),
    .pm_pl_aux_clk_freq             (pm_pl_aux_clk_freq),
    .perst_n_posedge                (perst_n_posedge),
    .pm_pmstate                     (pm_pmstate),
    .pm_aslk_pmctrl                 (pm_aslk_pmctrl),
// ------------- Outputs ----------------------------------
    .software_entr_l1               (software_entr_l1),
    .software_entr_l23              (software_entr_l23),
    .pm_aspm_l0s_en                 (pm_aspm_l0s_en),
    .pm_aspm_l1_en                  (pm_aspm_l1_en),
    .pm_xtlh_block_tlp              (pm_xtlh_block_tlp),
    .pm_radm_block_tlp              (pm_radm_block_tlp),
    .pm_xmt_turnoff                 (pm_xmt_turnoff),
    .pm_turnoff_timeout             (pm_turnoff_timeout),
    .pm_xmt_to_ack                  (pm_xmt_to_ack),
    .pm_xmt_pme                     (pm_xmt_pme),
    .pm_wake_l2_exit                (pm_wake_l2_exit),
    .pm_req_dwsp_turnoff            (pm_req_dwsp_turnoff),
    .pm_status                      (pm_status),
    .pm_pme_exit_l1                 (pm_pme_exit_l1)
    ,
    .pm_pme_resend_flag             (pm_pme_resend_flag)
    ,
    .pm_l2_entry_flag               (pm_l2_entry_flag)
);

pm_active_ctrl

#(  .INST               (INST),
    .PD_WIDTH           (`CX_PHY_PDOWN_WD),
    .P0                 (P0),
    .P1                 (P1),
    .P2                 (P2),
    .PL_AUX_CLK_FREQ_WD (`CX_PL_AUX_CLK_FREQ_WD),
    .PM_SYNC_DEPTH      (`CX_PCIE_SYNC_DEPTH)
    ,
    .L1SUB_CONTROL_WD   (`CX_L1SUB_CONTROL_WD),
    .PL_L1SUB_CONTROL_WD(`CX_PL_L1SUB_CONTROL_WD),
    .PM_CPL_TIMER_WD    (`CX_PM_CPL_TIMER_WD)
) u_pm_active_ctrl(
    .pm_usp_link_state              (shadow_pm_usp_link_state),
    .pm_dsp_link_state              (shadow_pm_dsp_link_state),
    .pm_en_core_clk                 (pm_en_core_clk),
    .pm_phy_rst_done                (pm_phy_rst_done),
    .pmu_l2_pd                      (pmu_l2_pd),
    .pl_l1_clk_sel                  (pm_pl_l1_clk_sel),
    .pm_lane_active                 (pm_lane_active),
    .smlh_cal_req                   (1'b0),
    .gasket_drive_pd                (gasket_drive_pd),
    .gasket_drive_pd_no_clk         (gasket_drive_pd_no_clk),
    .gasket_powerdown_p1_2          (gasket_powerdown_p1_2),
    .gasket_clk_req_n               (gasket_clk_req_n),
    .gasket_sel_aux_clk             (gasket_sel_aux_clk),
    .pm_det_l2                      (pm_det_l2),
    .pre_pm_exit_p2                 (pre_pm_exit_p2),
    .link_req_rst_not               (link_req_rst_not),               
    .aux_clk_active                 (pm_aux_clk_active),
    .aux_clk_inactive               (pm_aux_clk_inactive),
    .app_clk_req_n                  (app_clk_req_n),
    .phy_clk_req_n                  (phy_clk_req_n),
    .pm_set_phy_p1                  (pm_set_phy_p1),
    .pwr_rst_n                      (pwr_rst_n),
    .aux_clk                        (aux_clk),
    .perst_n                        (pm_sync_perst_n),
    .perst_n_posedge                (perst_n_posedge),
    .pm_req_iso_vmain_to_vaux       (1'b0),
    .switch_device                  (switch_device),
    .upstream_port                  (pm_upstream_port),
    .smlh_in_l0                     (smlh_in_l0),
    .smlh_in_l23                    (smlh_in_l23),
    .pre_pm_phy_powerdown           (int_cpcie_powerdown),
    .pm_clk_pm_en                   (pm_clk_pm_en),
    .phy_mac_rxelecidle             (int_pm_rxelecidle),
    .aux_pm_det                     (sys_aux_pwr_det),
    .phy_link_up                    (shadow_smlh_link_up),
    .ltssm_txelecidle               (int_cpcie_txelecidle),
    .current_data_rate              (pm_current_data_rate),
    .pm_l1sub_control               (pm_l1sub_control),
    .pm_pl_l1sub_control            (pm_pl_l1sub_control),
    .phy_mac_pclkack_n              (phy_mac_gk_pclkack_n),
    .pm_clkreq_in_n                 (pm_clkreq_in_n),
    .pm_pl_l1_exit_mode             (pm_pl_l1_exit_mode),
    .pm_pl_aux_clk_freq             (pm_pl_aux_clk_freq),
    .pm_pl_gen3_zrxdc_noncompl      (pm_pl_gen3_zrxdc_noncompl),
    .app_l1sub_disable              (app_l1sub_disable),
    .pm_cfg_phy_powerdown_p2_options (pm_cfg_phy_powerdown_p2_options),
    .gasket_maxpclk_removed         (gasket_maxpclk_removed),
    .gasket_maxpclk_back_on         (gasket_maxpclk_back_on),
    .current_powerdown_p2           (pm_current_powerdown_p2),
    .pm_perst_powerdown             (pm_perst_powerdown),
    .pm_req_non_sticky_rst          (pm_req_non_sticky_rst),
    .pm_l1sub_fsm_rst               (pm_l1sub_fsm_rst),
    .pm_cxl_mode_enable             (shadow_pl_cxl_mode_enable),
    .lp_sdb_l1sub_aspm              (shadow_lp_sdb_l1sub_aspm),
    .lp_sdb_l1sub_pcipm             (shadow_lp_sdb_l1sub_pcipm),
    .pm_wakeup_event                (pm_wakeup_event),
    .pm_clk_ack                     (pm_clk_ack),
    .pm_linkst_en_core_clk          (pm_linkst_en_core_clk)
// Outputs
  // Configuration Interface
   ,.pm_linkst_in_l0                (pm_linkst_in_l0)
   ,.l1sub_state                    (pm_l1sub_state)
   ,.pm_pclkack_timeout             (pm_pclkack_timeout)
   ,.pm_in_l11                      (pm_in_l11)
   ,.pm_in_l12                      (pm_in_l12)
   ,.pm_in_l1_short                 (pm_in_l1_short)
   ,.pm_in_l1_cpm                   (pm_in_l1_cpm)
   ,.pm_in_l1_abort                 (pm_in_l1_abort)
   ,.pm_int_phy_powerdown           (pm_int_phy_powerdown)

  // Application and PIPE Interfaces
   ,.pm_phy_txelecidle              (phy_if_cpcie_txelecidle)
   ,.pm_curnt_state                 (pm_curnt_state)
   ,.wake                           (wake)
   ,.local_ref_clk_req_n            (local_ref_clk_req_n)
   ,.pm_linkst_in_l1                (pm_linkst_in_l1)
   ,.pm_linkst_in_l2                (pm_linkst_in_l2)
   ,.pm_linkst_l2_exit              (pm_linkst_l2_exit)
   ,.pm_linkst_in_l3                (pm_linkst_in_l3)
   ,.pm_linkst_in_l1sub             (pm_linkst_in_l1sub)

  // CX_LOG_PHY: Physical Layer Interface
   ,.pm_hold_exit_l1                (pm_hold_exit_l1)
   ,.pm_link_exit_l1                (pm_link_exit_l1)
   ,.pm_link_exit_l23               (pm_link_exit_l23)
   ,.pm_smlh_l1_2_latched           (pm_smlh_l1_2_latched)
   ,.pm_smlh_l1_n_latched           (pm_smlh_l1_n_latched)

  // PM Controller Internal Connections
   ,.pm_phyinl1                     (pm_phyinl1)            // PM Link Controller: PM is in L1 and current power down state is P1
   ,.pm_phyinl2                     (pm_phyinl2)            // PM Link Controller: PM is in L2 and current power down state is P2
   ,.pm_clk_req                     (pm_clk_req)            // PM Link Controller: LogPHY request to remove Link Layer clock gating
   ,.pm_en_core_clk_gating          (pm_en_core_clk_gating) // PM Link Controller: Enable core_clk gating
   ,.pm_linkst_sel_aux_clk          (pm_linkst_sel_aux_clk) // PM Clock Controller: Select slow clock for aux_clk
   ,.pm_l1sub_sel_aux_clk           (pm_l1sub_sel_aux_clk)  // PM Clock Controller:
   ,.pm_linkst_in_l23rdy            (pm_linkst_in_l23rdy)   // PM Reset Controller/PMU/Gasket/Application: Power management is on entry to L2 state
   ,.pm_req_exit_p2                 (pm_req_exit_p2)
   ,.cfg_trgt_l1cpm                 (cfg_trgt_l1cpm)
   ,.l1sub_state_is_l1_u            (l1sub_state_is_l1_u)
   ,.cfg_trgt_l1sub                 (cfg_trgt_l1sub)
   ,.l1sub_l11_next                 (pm_l1sub_l11_next)
   ,.l1sub_l12_next                 (pm_l1sub_l12_next)
   ,.l1sub_abort_next               (pm_l1sub_abort_next)
   ,.l1sub_req_p1cpm                (pm_l1sub_req_p1cpm)
   ,.pm_l1sub_clk_req_n             (pm_l1sub_clk_req_n)
   ,.pm_l1_cpm_exit                 (pm_l1_cpm_exit)
   ,.pm_phy_powerdown               (phy_if_cpcie_pm_powerdown)
   ,.mac_phy_rxelecidle_disable     (pm_phy_rxelecidle_disable)
   ,.mac_phy_txcommonmode_disable   (pm_phy_txcommonmode_disable)
   ,.pm_l1sub_pg_enable             (pm_l1sub_pg_enable)
   ,.pm_l1sub_pg_disable            (pm_l1sub_pg_disable)
   ,.pm_state_trans3_flag           (pm_state_trans3_flag)
   ,.pm_state_trans4_flag           (pm_state_trans4_flag)
   ,.pm_state_trans5_flag           (pm_state_trans5_flag)

  // Link Layer Interface
); // u_pm_active_ctrl

assign pm_en_aux_clk_g = 1'b1;

assign pmu_l2_pd = 1'b0;

pm_shadow

#(
  .INST (INST),
  .NL   (`CX_NL)
) u_pm_shadow (
    // Inputs
    .aux_clk                          (aux_clk),
    .pwr_rst_n                        (pwr_rst_n),
    .smlh_link_up                     (smlh_link_up),
    .current_data_rate                (current_data_rate),
    .rmlh_descrambled_even_parity     (rmlh_descrambled_even_parity),
    .xmlh_scramble_even_parity        (xmlh_scramble_even_parity),
    .pm_update                        (1'b0),
    .pm_update_perst                  (1'b0),
    .pm_hold                          (1'b0),
    .pm_hold_perst                    (1'b0),
    .rstctl_ltssm_enable              (rstctl_ltssm_enable),
    .trgt_cpl_lut_empty               (trgt_cpl_lut_empty),
    .brdg_mstr_xfer_pending           (brdg_mstr_xfer_pending),
    .radm_idle                        (radm_idle),
    .cdm_pm_state_trans_tracker       (cdm_pm_state_trans_tracker),
    .smlh_pm_state_trans1_flag        (smlh_pm_state_trans1_flag),
    .smlh_pm_state_trans2_flag        (smlh_pm_state_trans2_flag),
    .pm_usp_link_state                (pm_usp_link_state),
    .pm_dsp_link_state                (pm_dsp_link_state),
    .pm_linkst_in_l0s                 (pm_linkst_in_l0s),
    .pm_linkst_in_l0                  (pm_linkst_in_l0),
    .pm_l1_entry_started              (pm_l1_entry_started),
    .pm_aspm_l1_enter_ready           (pm_aspm_l1_enter_ready),
    .pm_l1_in_progress                (pm_l1_in_progress),
    .latch_as_entr_l1                 (latch_as_entr_l1),
    .pl_pcie_phyinl1                  (pl_pcie_phyinl1),
    .pl_pcie_phyinl2                  (pl_pcie_phyinl2),
    .pl_pcie_state_l1                 (pl_pcie_state_l1),
    .pl_pcie_state_l2                 (pl_pcie_state_l2),
    .pl_pcie_state_active             (pl_pcie_state_active),
    .pl_pcie_link_up                  (pl_pcie_link_up),
    .pl_cxl_phyinl1                   (pl_cxl_phyinl1),
    .pl_cxl_phyinl2                   (pl_cxl_phyinl2),
    .pl_cxl_state_l1                  (pl_cxl_state_l1),
    .pl_cxl_state_l2                  (pl_cxl_state_l2),
    .pl_cxl_mode_enable               (pl_cxl_mode_enable),
    .lp_sdb_l1sub_aspm                (lp_sdb_l1sub_aspm),
    .lp_sdb_l1sub_pcipm               (lp_sdb_l1sub_pcipm),
    .pm_prot_idle_flag                (pm_prot_idle_flag),
    .pm_xdlh_enter_l23                (pm_xdlh_enter_l23),
    // Outputs
    .pm_smlh_link_up                  (shadow_smlh_link_up),
    .pm_ltssm_enable                  (pm_ltssm_enable),
    .pm_current_data_rate             (pm_current_data_rate)
    ,
    .pm_rmlh_descrambled_even_parity  (pm_rmlh_descrambled_even_parity),
    .pm_xmlh_scramble_even_parity     (pm_xmlh_scramble_even_parity)
    ,
    .pm_trgt_cpl_lut_empty_n          (pm_trgt_cpl_lut_empty_n)
    ,
    .pm_radm_idle_n                   (pm_radm_idle_n)
    ,
    .latched_rxdetected              (latched_rxdetected),
    .pm_latched_rxdetected           (pm_latched_rxdetected)
    ,
    .pm_cdm_pm_state_trans_tracker    (pm_cdm_pm_state_trans_tracker),
    .pm_smlh_pm_state_trans1_flag     (pm_smlh_pm_state_trans1_flag),
    .pm_smlh_pm_state_trans2_flag     (pm_smlh_pm_state_trans2_flag)
    ,
    .shadow_pm_usp_link_state           (shadow_pm_usp_link_state),
    .shadow_pm_dsp_link_state           (shadow_pm_dsp_link_state),
    .shadow_pm_linkst_in_l0s            (shadow_pm_linkst_in_l0s),
    .shadow_pm_linkst_in_l0             (shadow_pm_linkst_in_l0),
    .shadow_pm_l1_entry_started         (shadow_pm_l1_entry_started),
    .shadow_pm_aspm_l1_enter_ready      (shadow_pm_aspm_l1_enter_ready),
    .shadow_pm_l1_in_progress           (shadow_pm_l1_in_progress),
    .shadow_latch_as_entr_l1            (shadow_latch_as_entr_l1),
    .shadow_pl_pcie_phyinl1             (shadow_pl_pcie_phyinl1),
    .shadow_pl_pcie_phyinl2             (shadow_pl_pcie_phyinl2),
    .shadow_pl_pcie_state_l1            (shadow_pl_pcie_state_l1),
    .shadow_pl_pcie_state_l2            (shadow_pl_pcie_state_l2),
    .shadow_pl_pcie_state_active        (shadow_pl_pcie_state_active),
    .shadow_pl_pcie_link_up             (shadow_pl_pcie_link_up),
    .shadow_pl_cxl_phyinl1              (shadow_pl_cxl_phyinl1),
    .shadow_pl_cxl_phyinl2              (shadow_pl_cxl_phyinl2),
    .shadow_pl_cxl_state_l1             (shadow_pl_cxl_state_l1),
    .shadow_pl_cxl_state_l2             (shadow_pl_cxl_state_l2),
    .shadow_pl_cxl_mode_enable          (shadow_pl_cxl_mode_enable),
    .shadow_lp_sdb_l1sub_aspm           (shadow_lp_sdb_l1sub_aspm),
    .shadow_lp_sdb_l1sub_pcipm          (shadow_lp_sdb_l1sub_pcipm),
    .shadow_pm_prot_idle_flag           (shadow_pm_prot_idle_flag),
    .shadow_pm_xdlh_enter_l23           (shadow_pm_xdlh_enter_l23)
);

// -------------------------------------------------------------------------------------
// PM wakeup logic
// -------------------------------------------------------------------------------------
// Temporary solution for multistream architecture combine all HV inputs to 1 signal and connect
// to client0_tlp_hv port of pm_wakeup.
logic int_client_wakeup_hv;
logic [`N_XALI_IF-1:0] int_xali_wakeup_hv;
always_comb begin : xali_wakeup_PROC
  int_xali_wakeup_hv = '0;
  for(int i = 0; i < `N_XALI_IF; i++)
    int_xali_wakeup_hv[i] = xali_xaim_pkt[i].hdr.tlp_hv;
end : xali_wakeup_PROC

assign int_client_wakeup_hv = (|int_xali_wakeup_hv) ;

pm_wakeup

// Parameters
#( 
  .INST (INST),
  .NF   (`CX_NFUNC),
  .NVC  (`CX_NVC),
  .CPL_LUT_DEPTH  (`CX_CPL_LUT_DEPTH),
  .PM_SYNC_DEPTH  (`CX_PCIE_SYNC_DEPTH)
) u_pm_wakeup (
    // Inputs
    .aux_clk                      (aux_clk),
    .pwr_rst_n                    (pwr_rst_n),
    .pm_radm_idle_n               (pm_radm_idle_n),
    .edma_xfer_pending            (edma_xfer_pending),
    .slv_awvalid                  (slv_awvalid),
    .slv_arvalid                  (slv_arvalid),
    .slv_wvalid                   (slv_wvalid),
    .brdg_dbi_xfer_pending        (brdg_dbi_xfer_pending),
    .brdg_slv_xfer_pending        (brdg_slv_xfer_pending),
    .lti_xfer_pending             (1'b0),
    .local_msi_xfer_pending             (1'b0),
    .pm_trgt_cpl_lut_empty_n      (pm_trgt_cpl_lut_empty_n),
    .client0_tlp_hv               (int_client_wakeup_hv),
    .client1_tlp_hv               ('0),
    .client2_tlp_hv               ('0),
    .app_obff_idle_msg_req        (app_obff_idle_msg_req),
    .app_obff_obff_msg_req        (app_obff_obff_msg_req),
    .app_obff_cpu_active_msg_req  (app_obff_cpu_active_msg_req),
    .app_xfer_pending             (app_xfer_pending),
    .upstream_port                (pm_upstream_port),
    .switch_device                (switch_device),
    .cfg_link_dis                 (cfg_link_dis),
    .cfg_link_retrain             (cfg_link_retrain),
    .cfg_lpbk_en                  (cfg_lpbk_en),
    .cfg_2nd_reset                (cfg_2nd_reset),
    .cfg_plreg_reset              (cfg_plreg_reset),
    .app_init_rst                 (app_init_rst),
    .cfg_directed_speed_change    (cfg_directed_speed_change),
    .cfg_directed_width_change    (cfg_directed_width_change),
    .ven_msg_req                  (ven_msg_req),
    .ven_msi_req                  (ven_msi_req),
    .app_ltr_msg_req              (app_ltr_msg_req),
    .app_unlock_msg               (app_unlock_msg),
    .msg_gen_unlock_grant         (msg_gen_unlock_grant),
    .smlh_link_up                 (shadow_pl_pcie_link_up),
    .pm_aspm_l1_timer_enable      (pm_aspm_l1_timer_enable),
    .pm_req_iso_vmain_to_vaux     (1'b0),
    .pm_l1_in_progress            (shadow_pm_l1_in_progress),
    .pm_en_aux_clk_g              (pm_en_aux_clk_g),
    .clkreq_in_n                  (clkreq_in_n),
    .lbc_active                   (lbc_active),
    .msg_gen_hv                   (msg_gen_hv),
    .lbc_cpl_hv                   (lbc_cpl_hv),
    .pm_wake_req                  (pm_wake_req),
    .lp_pcie_l1_exit              (lp_pcie_l1_exit),
    .lp_pcie_wake_req             (lp_pcie_wake_req),
    .pl_pcie_wake_ack             (pl_pcie_wake_ack),
    .pl_pcie_state_l1             (shadow_pl_pcie_state_l1),
    .pl_pcie_state_l2             (shadow_pl_pcie_state_l2),
    .lp_cxl_l1_exit               (lp_cxl_l1_exit),
    .lp_cxl_wake_req              (lp_cxl_wake_req),
    .pl_cxl_wake_ack              (pl_cxl_wake_ack),
    .pl_cxl_state_l1              (shadow_pl_cxl_state_l1),
    .pl_cxl_state_l2              (shadow_pl_cxl_state_l2),
    .app_req_exit_l1              (app_req_exit_l1),
    .one_dwsp_exit_l1             (one_dwsp_exit_l1),
    .latch_as_entr_l1             (shadow_latch_as_entr_l1),
    .software_entr_l23            (software_entr_l23),
    .pm_pme_exit_l1               (pm_pme_exit_l1),
    .pm_wake_l2_exit              (pm_wake_l2_exit),
    .xdlh_not_expecting_ack       (xdlh_not_expecting_ack),
    .pm_clkreq_in_n               (pm_clkreq_in_n),
    .cxl_cache_slv_req            (cxl_cache_slv_req),
    .pm_cxl_cache_slv_req         (pm_cxl_cache_slv_req),
    .cxl_mem_slv_req              (cxl_mem_slv_req),
    .pm_cxl_mem_slv_req           (pm_cxl_mem_slv_req),
    .ptm_updating                 (ptm_updating),
    // Outputs
    .pm_wake_init_rst             (pm_init_rst),
    .pm_wake_unlock_msg_req       (pm_unlock_msg_req),
    .pm_wake_l1_pg_exit           (pm_wake_l1_pg_exit),
    .pm_wake_l1_pg_ack            (pm_wake_l1_pg_ack),
    .pm_wake_any_if_pending       (pm_wake_any_if_pending),
    .pm_wake_dbi_pending          (pm_wake_dbi_pending),
    .pm_wake_block_pg             (pm_wake_block_pg)
    ,
    .pm_smlh_link_retrain         (pm_smlh_link_retrain),
    .pm_wake_req_exit_l0s         (pm_wake_req_exit_l0s)
);

assign pm_pl_wake_ack = pm_wake_ack;
assign pm_pl_clk_req  = pm_clk_req;
assign pm_pl_phyinl1  = pm_phyinl1;
assign pm_pl_phyinl2  = pm_phyinl2;

pm_link_ctrl
 u_pm_link_ctrl (
    .aux_clk                      (aux_clk),
    .pwr_rst_n                    (pwr_rst_n),
    .pm_en_core_clk               (pm_en_core_clk),
    .pm_en_core_clk_gating        (pm_en_core_clk_gating),
    .pl_phyinl1                   (pm_phyinl1),
    .pl_phyinl2                   (pm_phyinl2),
    .pm_clk_req                   (pm_clk_req),
    .pm_clk_ack                   (pm_clk_ack),
    .pl_pcie_clk_req              (pl_pcie_clk_req),
    .lp_pcie_clk_ack              (lp_pcie_clk_ack),
    .pl_cxl_clk_req               (pl_cxl_clk_req),
    .lp_cxl_clk_ack               (lp_cxl_clk_ack),
    .pm_wake_ena                  (!gasket_drive_pd_no_clk),
    .pm_wake_req                  (pm_wake_req),
    .pm_wake_ack                  (pm_wake_ack),
    .pm_wakeup_event              (pm_wakeup_event),
    .pm_linkst_en_core_clk        (pm_linkst_en_core_clk)
);

// ----------------------------------------------------------------------------
// PM reset control
// ----------------------------------------------------------------------------
pm_rst_control

    // Parameters
    #(
        .NL             (`CX_NL),
        .INST           (INST),
        .PM_SYNC_DEPTH  (`CX_PCIE_SYNC_DEPTH)
    ) u_pm_rst_control (
    // Inputs
    .pm_req_iso_vmain_to_vaux   (1'b0),
    .aux_clk                    (aux_clk),
    .pwr_rst_n                  (pwr_rst_n),
    .core_rst_n                 (core_rst_n),
    .perst_n                    (perst_n),
    .pm_linkst_in_l23rdy        (pm_linkst_in_l23rdy),
    .aux_clk_active             (pm_aux_clk_active),
    .aux_clk_inactive           (pm_aux_clk_inactive),
    .pm_phy_perst_on_warm_reset (pm_phy_perst_on_warm_reset),
    .link_req_rst_not           (link_req_rst_not),
    .app_hold_phy_rst           (app_hold_phy_rst),
    .pm_phy_rst_timer           (pm_phy_rst_timer),
    .pm_pma_phy_rst_delay_timer (pm_pma_phy_rst_delay_timer),
    .phystatus_pclk_ready       (phystatus_pclk_ready),
    // Outputs
    .pm_rst_req_phy_rst         (pm_req_phy_rst),
    .pm_rst_req_phy_perst       (pm_req_phy_perst),
    .pm_rst_req_core_rst        (pm_req_core_rst),
    .pm_rst_req_sticky_rst      (pm_req_sticky_rst),
    .pm_rst_req_non_sticky_rst  (pm_req_non_sticky_rst),
    .pm_rst_core_rst_done       (pm_core_rst_done),
    .pm_rst_sync_perst_n        (pm_sync_perst_n),
    .pm_rst_sel_aux_clk         (pm_rst_sel_aux_clk),
    .pm_rst_perst_n_re          (perst_n_posedge),
    .pm_rst_det_l2              (pm_det_l2)
    ,
    .pm_rst_perst_powerdown     (pm_perst_powerdown),
    .pm_rst_set_phy_p1          (pm_set_phy_p1),
    .pm_rst_phy_rst_done        (pm_phy_rst_done)
    ,.pre_pm_exit_p2            (pre_pm_exit_p2)
    ,.pclk_hs_rst               (pclk_hs_rst) 
    ,
    .pm_rst_l1sub_fsm_rst       (pm_l1sub_fsm_rst)
);

// ----------------------------------------------------------------------------
// Receiver electrical idle detection
// ----------------------------------------------------------------------------
rxeidle_squelch
 u_rxeidle_squelch [`CX_NL-1:0] (
    //    ----------------- Inputs ----------------------
    .iphy_mac_rxelecidle (phy_mac_rxelecidle_int[`CX_NL-1:0]),
    .aux_clk             (aux_clk),
    .rst_n               (pwr_rst_n),
    //    ----------------- Outputs ----------------------
    .ophy_mac_rxelecidle (sqlchd_rxelecidle[`CX_NL-1:0])
);

 assign int_pm_rxelecidle          = sqlchd_rxelecidle;

// ----------------------------------------------------------------------------
// PHY Interface
// ----------------------------------------------------------------------------
phy_if_cpcie
 #(
    // Parameters
    .INST           (INST),
    .PDWN_WIDTH     (`CX_PHY_PDOWN_WD),
    .NL             (`CX_NL),
    .PHY_NB         (`CX_PHY_NB),
    .TX_COEF_WD     (`CX_TX_COEF_WD),
    .RX_PSET_WD     (`CX_RX_PSET_WD),
    .TX_FS_WD       (`CX_TX_FS_WD),
    .TX_PSET_WD     (`CX_TX_PSET_WD),
    .TX_CRSR_WD     (`CX_TX_CRSR_WD),
    .RX_PRESET_WD   (`CX_NL*`CX_RX_PSET_WD),
    .FS_WD          (`CX_NL*`CX_TX_FS_WD),
    .LF_WD          (`CX_NL*`CX_TX_FS_WD),
    .PSET_INDEX_WD  (`CX_NL*`CX_TX_PSET_WD),
    .V7_DEEMPH_WD   (`CX_NL*`CX_TX_CRSR_WD),
    .TX_DEEMPH_WD   (`CX_PHY_TXDEEMPH_WD),
    .PHY_RATE_WD    (`CX_PHY_RATE_WD),
    .PHY_WIDTH_WD   (`CX_PHY_WIDTH_WD),
    .P1             (P1),
    .NL_X2          (`CX_NL*2),
    .L2NL           (`CX_L2NL)
) u_phy_if_cpcie (
    // Inputs
    .clk                            (aux_clk),
    .rst_n                          (pwr_rst_n),

    .update_perst                   (1'b0),
    .hold_perst                     (1'b0),
    .hold_data                      (1'b0),
    .update                         (1'b0)
    ,
    .mac_phy_rxelecidle_disable     (gasket_rxelecidle_disable),
    .mac_phy_txcommonmode_disable   (gasket_txcommonmode_disable)
    ,
    .cfg_phy_control                (cfg_phy_control),
    .cfg_comm_clk_config            (cfg_comm_clk_config),
    .mac_phy_powerdown              (mac_phy_powerdown),
    .mac_phy_txelecidle             (mac_phy_txelecidle)
    ,
    .xmlh_sris_enable               (xmlh_sris_enable)
    ,
    .mac_phy_txdata                 (mac_phy_txdata),
    .mac_phy_txdetectrx_loopback    (mac_phy_txdetectrx_loopback),
    .mac_phy_txcompliance           (mac_phy_txcompliance),
    .mac_phy_rxpolarity             (mac_phy_rxpolarity),
    .ltssm_rxpolarity               (ltssm_rxpolarity),
    .mac_phy_width                  (mac_phy_width),
    .mac_phy_serdes_arch            (mac_phy_serdes_arch),
    .mac_phy_rxwidth                (mac_phy_rxwidth),
    .serdes_pipe_rxready            (serdes_pipe_rxready),
    .serdes_pipe_turnoff_lanes      (serdes_pipe_turnoff_lanes),
    .mac_phy_pclk_rate              (mac_phy_pclk_rate),
    .mac_phy_rxstandby              (mac_phy_rxstandby)
    ,
    .mac_phy_rate                   (mac_phy_rate),
    .mac_phy_txdeemph               (mac_phy_txdeemph)
    ,
    .mac_phy_txdatavalid            (mac_phy_txdatavalid)
    ,
    .mac_phy_rxeqeval               (mac_phy_rxeqeval),
    .mac_phy_dirchange              (mac_phy_dirchange),
    .mac_phy_smlh_coef_rtx          (mac_phy_smlh_coef_rtx)
    ,
    .mac_phy_mbus                   (mac_phy_mbus)
    ,
    .rx_lane_flip_en                (rx_lane_flip_en),
    .tx_lane_flip_en                (tx_lane_flip_en),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl)
    // Outputs
    ,
    .phy_if_cpcie_rxelecidle_disable    (phy_if_cpcie_rxelecidle_disable),
    .phy_if_cpcie_txcommonmode_disable  (phy_if_cpcie_txcommonmode_disable)
    ,
    .phy_if_cfg_phy_control             (phy_if_cfg_phy_control),
    .phy_if_cpcie_powerdown             (int_cpcie_powerdown),
    .phy_if_cpcie_txelecidle            (int_cpcie_txelecidle)
    ,
    .phy_if_cpcie_xmlh_sris_enable      (phy_if_cpcie_xmlh_sris_enable)
    ,
    .phy_if_cpcie_txdata                (phy_if_cpcie_txdata),
    .phy_if_cpcie_txdetectrx_loopback   (phy_if_cpcie_txdetectrx_loopback),
    .phy_if_cpcie_txcompliance          (phy_if_cpcie_txcompliance),
    .phy_if_cpcie_rxpolarity            (phy_if_cpcie_rxpolarity),
    .phy_if_cpcie_width                 (phy_if_cpcie_width),
    .phy_if_cpcie_serdes_arch           (phy_if_cpcie_serdes_arch),
    .phy_if_cpcie_rxwidth               (phy_if_cpcie_rxwidth),
    .pm_serdes_pipe_rxready             (pm_serdes_pipe_rxready),
    .pm_serdes_pipe_turnoff_lanes       (pm_serdes_pipe_turnoff_lanes),
    .phy_if_cpcie_pclk_rate             (phy_if_cpcie_pclk_rate),
    .phy_if_cpcie_rxstandby             (phy_if_cpcie_rxstandby)
    ,
    .phy_if_cpcie_rate                  (phy_if_cpcie_rate),
    .phy_if_cpcie_txdeemph              (phy_if_cpcie_txdeemph)
    ,
    .phy_if_cpcie_txdatavalid           (phy_if_cpcie_txdatavalid)
    ,
    .phy_if_cpcie_rxeqeval              (phy_if_cpcie_rxeqeval),
    .phy_if_cpcie_dirchange             (phy_if_cpcie_dirchange),
    .phy_if_cpcie_smlh_coef_rtx         (phy_if_cpcie_smlh_coef_rtx)
    ,
    .phy_if_cpcie_mbus                 (phy_if_cpcie_mbus)
    ,
    .pm_rx_lane_flip_ctrl               (pm_rx_lane_flip_ctrl),
    .pm_tx_lane_flip_ctrl               (pm_tx_lane_flip_ctrl),
    .pm_rx_pol_lane_flip_ctrl           (pm_rx_pol_lane_flip_ctrl)
    ,.phy_if_cfg_comm_clk_config        (phy_if_cfg_comm_clk_config)
);

pm_cfg

  // Parameters
  #(
    .INST                 (1'b0),
    .NF                   (`CX_NFUNC),
    .NL                   (`CX_NL),
    .ASLK_CTRL_WD         (`CX_NFUNC*2),
    .L1SUB_CONTROL_WD     (`CX_L1SUB_CONTROL_WD),
    .PL_L1SUB_CONTROL_WD  (`CX_PL_L1SUB_CONTROL_WD),
    .PL_AUX_CLK_FREQ_WD   (`CX_PL_AUX_CLK_FREQ_WD),
    .PDWN_WIDTH           (`CX_PHY_PDOWN_WD),
    .P2NOBEACON_ENABLE_VAL(P2NOBEACON_ENABLE_VAL),
    .P2NOBEACON           (P2NOBEACON),
    .P2                   (P2),
    .PIPE_OPTIONAL_PCLKCHANGE_HS (`CX_PIPE_OPTIONAL_PCLKCHANGE_HS),
    .DEFAULT_PHY_PERST_ON_WARM_RESET (`DEFAULT_PHY_PERST_ON_WARM_RESET),
    .NFUNC_WD             (`CX_NFUNC_WD),
    .NVF                  (1),
    .BUS_NUM_WD           (`CX_BUSNUM_WD),
    .DEV_NUM_WD           (`CX_DEVNUM_WD)
  ) u_pm_cfg (
  // Inputs
  .aux_clk                        (aux_clk),
  .pwr_rst_n                      (pwr_rst_n),
  .perst_n                        (pm_sync_perst_n),
  .upstream_port                  (upstream_port),
  .en_iso                         (1'b0),
  .pm_hold                        (1'b0),
  .pm_hold_perst                  (1'b0),
  .pm_update                      (1'b0),
  .pm_update_perst                (1'b0),
  .pm_active_state                (1'b0),
  .pm_req_core_rst                (pm_req_core_rst),
  .cfg_aslk_pmctrl                (cfg_aslk_pmctrl),
  .cfg_aspm_l1_timer_enable       (cfg_aspm_l1_timer_enable),
  .cfg_upd_aslk_pmctrl            (cfg_upd_aslk_pmctrl),
  .cfg_aux_pm_en                  (cfg_aux_pm_en),
  .cfg_pme_en                     (cfg_pme_en),
  .cfg_pbus_num                   (cfg_pbus_num),
  .cfg_pbus_dev_num               (cfg_pbus_dev_num),
  .cfg_upd_aux_pm_en              (cfg_upd_aux_pm_en),
  .cfg_upd_pmcsr                  (cfg_upd_pmcsr),
  .cfg_upd_req_id                 (cfg_upd_req_id),
  .cfg_pme_cap                    (cfg_pme_cap),
  .cfg_upd_pme_cap                (cfg_upd_pme_cap),
  .pm_core_rst_done               (pm_core_rst_done),
  .cfg_pmstate                    (cfg_pmstate),
  .cfg_clk_pm_en                  (cfg_clk_pm_en),
  .cfg_l1sub_control              (cfg_l1sub_control),
  .cfg_pl_l1sub_control           (cfg_pl_l1sub_control),
  .cfg_pl_l1_exit_mode            (cfg_pl_l1_exit_mode),
  .cfg_pl_l1_clk_sel              (cfg_pl_l1_clk_sel),
  .cfg_p2nobeacon_enable          (cfg_p2nobeacon_enable),
  .cfg_utility                    (cfg_utility),
  .pm_cfg_utility                 (pm_cfg_utility),
  .cfg_pipe_optional_pclkchange_hs(cfg_pipe_optional_pclkchange_hs),
  .cfg_phy_perst_on_warm_reset    (cfg_phy_perst_on_warm_reset),
  .cfg_phy_rst_timer              (cfg_phy_rst_timer),
  .cfg_pma_phy_rst_delay_timer    (cfg_pma_phy_rst_delay_timer),
  .cfg_pl_aux_clk_freq            (cfg_pl_aux_clk_freq),
  .cfg_pl_gen3_zrxdc_noncompl     (cfg_pl_gen3_zrxdc_noncompl),
  .cfg_link_capable               (cfg_link_capable),
  // Outputs
  .pm_cfg_aslk_pmctrl             (pm_aslk_pmctrl),
  .pm_cfg_aux_pm_en               (pm_aux_pm_en),
  .pm_aspm_l1_timer_enable        (pm_aspm_l1_timer_enable),
  .pm_cfg_pme_en                  (pm_pme_en),
  .pm_cfg_pbus_num                (pm_bus_num),
  .pm_cfg_pbus_dev_num            (pm_dev_num),
  .pm_cfg_pme_cap                 (pm_pme_cap),
  .pm_cfg_pmstate                 (pm_pmstate),
  .pm_cfg_clk_pm_en               (pm_clk_pm_en),
  .pm_cfg_l1sub_control           (pm_l1sub_control),
  .pm_cfg_pl_l1sub_control        (pm_pl_l1sub_control),
  .pm_cfg_pl_l1_exit_mode         (pm_pl_l1_exit_mode),
  .pm_cfg_pl_l1_clk_sel           (pm_pl_l1_clk_sel),
  .pm_cfg_phy_powerdown_p2_options (pm_cfg_phy_powerdown_p2_options),
  .pm_pipe_optional_pclkchange_hs (pm_pipe_optional_pclkchange_hs),
  .pm_phy_perst_on_warm_reset     (pm_phy_perst_on_warm_reset),
  .pm_cfg_pl_aux_clk_freq         (pm_pl_aux_clk_freq)
  ,
  .pm_cfg_pl_gen3_zrxdc_noncompl  (pm_pl_gen3_zrxdc_noncompl)
  ,
  .pm_upstream_port               (pm_upstream_port)
  ,
  .pm_link_capable                (pm_link_capable),
  .pm_phy_rst_timer               (pm_phy_rst_timer),
  .pm_pma_phy_rst_delay_timer     (pm_pma_phy_rst_delay_timer)
);

// -----------------------------------------------------------------------
// To facilate level shifter insertion where required some nets are 
// passed through the pm_ctrl module first and the routed into the core logic
// -----------------------------------------------------------------------
assign pm_aux_clk_ft = aux_clk;
assign pm_sys_aux_pwr_det_ft = sys_aux_pwr_det;
assign pm_aux_clk_active_ft = aux_clk_active;
assign pm_xadm_client0_tlp_hv = 1'b0;
assign pm_xadm_client1_tlp_hv = 1'b0;
assign pm_xadm_client2_tlp_hv = 1'b0;


// -----------------------------------------------------------------------
// To facilate level shifter insertion where required some outputs of
// the pm_ctrl module are split with one version output directly to the IO.
// The other versions named *_split are fed back internally in the core.
// -----------------------------------------------------------------------
assign pm_pme_en_split = pm_pme_en;
assign pm_aux_pm_en_split = pm_aux_pm_en;

// -----------------------------------------------------------------------
// Phystatus tracker for powerdown P2 transition
// -----------------------------------------------------------------------
DWC_pcie_phystatus_if
 u_phystatus_if(
    // Inputs
    .aux_clk                      (aux_clk),
    .pipe_clk                     (pipe_clk),
    .pwr_rst_n                    (pwr_rst_n),
    .mac_phy_powerdown            (phy_if_cpcie_powerdown),
    .mac_phy_txcompliance         (phy_if_cpcie_txcompliance),
    .mac_phy_txdetectrx_loopback  (phy_if_cpcie_txdetectrx_loopback),
    .phy_mac_phystatus            (phy_mac_phystatus_int),
    .phy_mac_rxstatus             (phy_mac_rxstatus_int),
    .pm_cfg_p2_encoding           (pm_cfg_phy_powerdown_p2_options),
    .cfg_force_powerdown          (cfg_force_powerdown),
    .mac_phy_rate                 (phy_if_cpcie_rate),
    .current_data_rate            (pm_current_data_rate),
    .pm_link_capable              (pm_link_capable),
    .smlh_ltssm_state             (smlh_ltssm_state),
    .pm_sel_aux_clk               (pm_sel_aux_clk),
    .pm_perst_powerdown           (pm_perst_powerdown),
    // Outputs
    .pm_current_powerdown         (),
    .pm_current_powerdown_p2      (pm_current_powerdown_p2),
    .pm_current_powerdown_p1      (pm_current_powerdown_p1),
    .pm_current_powerdown_p0      (pm_current_powerdown_p0),
    .pm_rxdetected                (),
    .pm_powerdown_status          (pm_powerdown_status),
    .phystatus_if_sel_aux_clk     (phystatus_if_sel_aux_clk),
    .pm_lane_active               (pm_lane_active)
    ,.phystatus_done_pclk_always_trace (phystatus_if_phystatus_high)
    ,.phystatus_done_aux_clk      (phystatus_done_aux_clk)
    ,.phystatus_pclk_ready        (phystatus_pclk_ready)
);

// -----------------------------------------------------------------------
// PCLK change handshake control for PCLK as PHY input
// -----------------------------------------------------------------------
pm_pclkchange_ctrl
 #(
    .P_R_WD      (`PCLK_RATE_WD),
    .PHY_RATE_WD (`CX_PHY_RATE_WD),
    .NL          (`CX_NL)
) u_pm_pclkchange_ctrl (
    // Inputs
    .aux_clk                        (aux_clk               ),
    .pipe_clk                       (pipe_clk              ),
    .pwr_rst_n                      (pwr_rst_n             ),
    .perst_n                        (pm_sync_perst_n       ),
    .pm_lane_active                 (pm_lane_active        ),
    .phy_mac_pclkchangeok           (phy_mac_pclkchangeok  ),
    .phy_if_cpcie_rate              (phy_if_cpcie_rate     ),
    .phy_mac_phystatus              (phy_mac_phystatus_int ),
    .phy_if_cpcie_pclk_rate         (phy_if_cpcie_pclk_rate),
    .pm_req_phy_rst                 (pm_req_phy_rst        ),
    .link_req_rst_not               (link_req_rst_not      ),               
    .phystatus_done_auxclk          (phystatus_if_phystatus_high ),
    .pm_pipe_optional_pclkchange_hs (pm_pipe_optional_pclkchange_hs),
    // Outputs
    .pm_div_max_pclk_ratio          (pm_div_max_pclk_ratio ),
    .pclk_hs_rst                    (pclk_hs_rst), 
    .mac_phy_pclkchangeack          (mac_phy_pclkchangeack )
);

ltssm_latency_tracker
 #(
  .PL_AUX_CLK_FREQ_WD (`CX_PL_AUX_CLK_FREQ_WD)
) u_ltssm_latency_tracker (
    // Inputs
    .aux_clk                        (aux_clk               ),
    .pwr_rst_n                      (pwr_rst_n             ),
    .pm_perst_powerdown             (pm_perst_powerdown    ), 
    .aux_clk_active                 (aux_clk_active        ),
    .current_data_rate              (pm_current_data_rate  ),
    .pm_pl_aux_clk_freq             (pm_pl_aux_clk_freq    ),
    .cdm_pm_state_trans_tracker     (pm_cdm_pm_state_trans_tracker),
    .smlh_pm_state_trans1_flag      (pm_smlh_pm_state_trans1_flag),
    .smlh_pm_state_trans2_flag      (pm_smlh_pm_state_trans2_flag),
    .pm_state_trans3_flag           (pm_state_trans3_flag  ),
    .pm_state_trans4_flag           (pm_state_trans4_flag  ),
    .pm_state_trans5_flag           (pm_state_trans5_flag  ),
    // Outputs
    .pm_cdm_state_trans_tracking    (pm_cdm_state_trans_tracking)
);


pm_io_handler
 u_pm_io_handler (
  // Inputs
  .aux_clk                             (aux_clk),
  .pwr_rst_n                           (pwr_rst_n),
  .app_sris_mode                       (app_sris_mode),
  .xmlh_sris_enable                    (phy_if_cpcie_xmlh_sris_enable),
  .pm_perst_powerdown                  (pm_perst_powerdown),
  // Outputs
  .pm_io_handler_app_sris_mode         (pm_io_handler_app_sris_mode),
  .pm_io_handler_sris_enable           (pm_io_handler_sris_enable)
);


endmodule
